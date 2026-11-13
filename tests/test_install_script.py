"""Tests du modèle de script d'installation et des installateurs du backend."""
from __future__ import annotations

import ast
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from integration.backend import views
from integration.backend.views import (
    INSTALL_SCRIPT_TEMPLATE,
    generate_install_script,
    render_install_template,
)

from .conftest import make_deployment

ROOT = Path(__file__).resolve().parent.parent
BACKEND = ROOT / 'integration' / 'backend'
INSTALLERS = ['install-backend.sh', 'install-automated.sh', 'install-interactive-public.sh']


# --- Modèle de script ---------------------------------------------------------

def test_template_uses_lf_line_endings():
    assert b'\r\n' not in INSTALL_SCRIPT_TEMPLATE.read_bytes()


@pytest.mark.skipif(shutil.which('bash') is None, reason='bash indisponible')
def test_template_is_valid_bash():
    subprocess.run(['bash', '-n', str(INSTALL_SCRIPT_TEMPLATE)], check=True)


def test_render_rejects_missing_value():
    with pytest.raises(KeyError, match='manquants'):
        render_install_template('A={{A}} B={{B}}', {'A': '1'})


def test_render_rejects_unused_value():
    with pytest.raises(KeyError, match='inutilisés'):
        render_install_template('A={{A}}', {'A': '1', 'TYPO': '2'})


def test_render_does_not_reinterpret_inserted_values():
    # Une valeur contenant un marqueur ne doit pas être substituée à nouveau
    assert render_install_template('{{A}}-{{B}}', {'A': '{{B}}', 'B': 'x'}) == '{{B}}-x'


@pytest.mark.django_db
def test_generated_script_has_no_leftover_placeholder():
    script = generate_install_script(make_deployment())
    assert '{{' not in script and '}}' not in script


@pytest.mark.django_db
def test_crlf_template_is_normalised(tmp_path, monkeypatch):
    crlf = tmp_path / 'tpl.sh.tpl'
    crlf.write_bytes(INSTALL_SCRIPT_TEMPLATE.read_bytes().replace(b'\n', b'\r\n'))
    monkeypatch.setattr(views, 'INSTALL_SCRIPT_TEMPLATE', crlf)
    views._load_install_template.cache_clear()
    try:
        assert '\r' not in generate_install_script(make_deployment())
    finally:
        views._load_install_template.cache_clear()


# --- Installateurs : tous les fichiers nécessaires sont copiés ----------------

def _relative_imports(module: Path) -> set[str]:
    tree = ast.parse(module.read_text(encoding='utf-8'))
    return {
        f'{node.module.split(".")[0]}.py'
        for node in ast.walk(tree)
        if isinstance(node, ast.ImportFrom) and node.level == 1 and node.module
    }


def _runtime_dependencies() -> set[str]:
    """Fermeture des imports relatifs à partir de urls.py et admin.py."""
    todo, seen = ['urls.py', 'admin.py'], set()
    while todo:
        name = todo.pop()
        if name in seen:
            continue
        seen.add(name)
        todo.extend(_relative_imports(BACKEND / name) - seen)
    return seen


def _copied_files(installer: str) -> set[str]:
    text = (ROOT / installer).read_text(encoding='utf-8')
    match = re.search(r'BACKEND_FILES=\((.*?)\)', text, re.S)
    assert match, f'{installer} : tableau BACKEND_FILES introuvable'
    return set(match.group(1).split())


@pytest.mark.parametrize('installer', INSTALLERS)
def test_installer_copies_every_imported_module(installer):
    missing = _runtime_dependencies() - _copied_files(installer)
    assert not missing, f'{installer} ne copie pas : {sorted(missing)}'


@pytest.mark.parametrize('installer', INSTALLERS)
def test_installer_copies_script_template_and_commands(installer):
    text = (ROOT / installer).read_text(encoding='utf-8')
    assert INSTALL_SCRIPT_TEMPLATE.name in _copied_files(installer)
    assert 'management/commands/' in text


@pytest.mark.parametrize('installer', INSTALLERS)
def test_installer_lists_only_existing_files(installer):
    missing = {f for f in _copied_files(installer) if not (BACKEND / f).exists()}
    assert not missing
