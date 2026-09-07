import datetime as dt
import sys
import unittest
from test_collector import c


class CostsTest(unittest.TestCase):
    def test_provider_schemas_strip_private_details_and_filter_calendar_range(self):
        today = dt.date(2030, 1, 1)
        for provider, field in [('claude', 'totalCost'), ('codex', 'costUSD')]:
            doc = {'daily': [
                {'date': '2030-01-01', field: 12.34, 'privateField': 'never-forward'},
                {'date': '2029-12-03', field: 4.5},
                {'date': '2029-12-02', field: 999},
            ]}
            result = c.normalize_costs(doc, provider, today)
            self.assertEqual(result['daily'], {'2030-01-01': 12.34, '2029-12-03': 4.5})
            self.assertNotIn('never-forward', str(result))

    def test_invalid_or_duplicated_amounts_fail_closed(self):
        for value in [-1, float('nan'), float('inf'), True, None, '1.20']:
            with self.assertRaises(c.CollectionError):
                c.normalize_costs({'daily': [{'date': '2030-01-01', 'costUSD': value}]}, 'codex', dt.date(2030, 1, 1))
        row = {'date': '2030-01-01', 'totalCost': 1}
        with self.assertRaises(c.CollectionError):
            c.normalize_costs({'daily': [row, row]}, 'claude', dt.date(2030, 1, 1))

    def test_reader_warning_is_retained_without_exposing_raw_diagnostic(self):
        doc = c.run_collector([sys.executable, '-c',
            'import sys; print("private model could not be priced", file=sys.stderr); print(\'{"daily": []}\')'], diagnostics=True)
        self.assertTrue(doc['_hasWarnings'])
        result = c.normalize_costs(doc, 'codex', dt.date(2030, 1, 1))
        self.assertEqual(result['state'], 'partial')
        self.assertNotIn('private', str(result))

    def test_claude_missing_price_is_never_reported_as_complete(self):
        doc = {'daily': [{'date': '2030-01-01', 'totalCost': 1,
                        'modelBreakdowns': [{'missingPricing': True}]}]}
        self.assertEqual(c.normalize_costs(doc, 'claude', dt.date(2030, 1, 1))['state'], 'partial')
