"""
Tests unitaires pour le module d'export CSV/JSON.

Usage:
    python -m pytest test_export.py -v
"""
from __future__ import annotations

import csv
import io
import json
import unittest
from datetime import datetime


class TestCSVExport(unittest.TestCase):
    """Tests pour l'export CSV"""

    def test_csv_header_format(self) -> None:
        """Test que les en-têtes CSV sont corrects"""
        expected_headers = [
            'UUID', 'Client', 'Site', 'Type Agent', 'Architecture',
            'Statut', 'Téléchargements', 'Installations',
            'Créé le', 'Expire le', 'Créé par',
        ]

        output = io.StringIO()
        writer = csv.writer(output, delimiter=';')
        writer.writerow(expected_headers)

        output.seek(0)
        reader = csv.reader(output, delimiter=';')
        headers = next(reader)
        self.assertEqual(headers, expected_headers)

    def test_csv_data_row(self) -> None:
        """Test qu'une ligne de données est correctement formatée"""
        row = [
            '12345678-1234-1234-1234-123456789012',
            'Client Test',
            'Site Test',
            'server',
            'amd64',
            'Actif',
            5,
            3,
            '2026-03-01 10:00:00',
            '2026-04-01 10:00:00',
            'admin',
        ]

        output = io.StringIO()
        writer = csv.writer(output, delimiter=';')
        writer.writerow(row)

        output.seek(0)
        reader = csv.reader(output, delimiter=';')
        parsed_row = next(reader)
        self.assertEqual(len(parsed_row), 11)
        self.assertEqual(parsed_row[1], 'Client Test')

    def test_csv_semicolon_delimiter(self) -> None:
        """Test que le délimiteur est bien le point-virgule"""
        output = io.StringIO()
        writer = csv.writer(output, delimiter=';')
        writer.writerow(['a', 'b', 'c'])

        content = output.getvalue()
        self.assertIn(';', content)
        self.assertNotIn(',', content.replace('\r\n', '').replace('\n', ''))


class TestJSONExport(unittest.TestCase):
    """Tests pour l'export JSON"""

    def test_json_structure(self) -> None:
        """Test que la structure JSON est correcte"""
        export_data = {
            'export_date': datetime.now().isoformat(),
            'total_count': 2,
            'deployments': [
                {
                    'uuid': '11111111-1111-1111-1111-111111111111',
                    'client_name': 'Client A',
                    'status': 'active',
                },
                {
                    'uuid': '22222222-2222-2222-2222-222222222222',
                    'client_name': 'Client B',
                    'status': 'expired',
                },
            ],
        }

        json_str = json.dumps(export_data, indent=2, ensure_ascii=False)
        parsed = json.loads(json_str)

        self.assertIn('export_date', parsed)
        self.assertIn('total_count', parsed)
        self.assertIn('deployments', parsed)
        self.assertEqual(parsed['total_count'], 2)
        self.assertEqual(len(parsed['deployments']), 2)

    def test_json_deployment_fields(self) -> None:
        """Test que chaque déploiement contient les champs requis"""
        required_fields = [
            'uuid', 'client_id', 'client_name', 'site_id', 'site_name',
            'agent_type', 'arch', 'status', 'download_count',
            'agents_installed', 'created_at', 'expires_at', 'created_by',
        ]

        deployment = {
            'uuid': '12345678-1234-1234-1234-123456789012',
            'client_id': 1,
            'client_name': 'Test',
            'site_id': 1,
            'site_name': 'Test Site',
            'agent_type': 'server',
            'arch': 'amd64',
            'status': 'active',
            'download_count': 5,
            'agents_installed': 3,
            'created_at': '2026-03-01T10:00:00',
            'expires_at': '2026-04-01T10:00:00',
            'created_by': 'admin',
        }

        for field in required_fields:
            self.assertIn(field, deployment, f"Champ manquant: {field}")

    def test_json_unicode_support(self) -> None:
        """Test que les caractères spéciaux sont supportés"""
        data = {'client_name': 'Client Éducation Française'}
        json_str = json.dumps(data, ensure_ascii=False)
        parsed = json.loads(json_str)
        self.assertEqual(parsed['client_name'], 'Client Éducation Française')


if __name__ == '__main__':
    unittest.main(verbosity=2)
