import datetime as dt
import sys
import unittest
from test_collector import c


def row(provider='codex', date='2030-01-01', cost=1, model_cost=1):
    return {'period': date, 'agents': [{'agent': provider, 'totalCost': cost, 'totalTokens': 2,
        'modelBreakdowns': [{'cost': model_cost, 'inputTokens': 1, 'outputTokens': 1,
                            'cacheCreationTokens': 0, 'cacheReadTokens': 0}]}]}


class CostsTest(unittest.TestCase):
    def test_schemas_strip_private_details_and_filter_calendar_range(self):
        for provider in ('claude', 'codex'):
            rows = [row(provider, '2030-01-01', 12.34), row(provider, '2029-12-03', 4.5), row(provider, '2029-12-02', 999)]
            rows[0]['privateField'] = 'never-forward'
            result = c.normalize_costs({'daily': rows}, provider, dt.date(2030, 1, 1))
            self.assertEqual(result['daily'], {'2030-01-01': 12.34, '2029-12-03': 4.5})
            self.assertNotIn('never-forward', str(result))

    def test_invalid_or_duplicated_amounts_fail_closed(self):
        for value in [-1, float('nan'), float('inf'), True, None, '1.20', 10**1000]:
            with self.assertRaises(c.CollectionError):
                c.normalize_costs({'daily': [row(cost=value)]}, 'codex', dt.date(2030, 1, 1))
        with self.assertRaises(c.CollectionError):
            c.normalize_costs({'daily': [row(), row()]}, 'codex', dt.date(2030, 1, 1))

    def test_reader_warning_is_retained_without_exposing_raw_diagnostic(self):
        doc = c.run_collector([sys.executable, '-c',
            'import sys; print("private model could not be priced", file=sys.stderr); print(\'{"daily": []}\')'], diagnostics=True)
        result = c.normalize_costs(doc, 'codex', dt.date(2030, 1, 1))
        self.assertEqual(result['state'], 'partial')
        self.assertNotIn('private', str(result))

    def test_silent_unknown_or_mixed_models_are_never_complete(self):
        for provider in ('claude', 'codex'):
            for cost in (0, 1):
                entry = row(provider, cost=cost, model_cost=0)
                self.assertEqual(c.normalize_costs({'daily': [entry]}, provider, dt.date(2030, 1, 1))['state'], 'partial')
            self.assertEqual(c.normalize_costs({'daily': [row(provider)]}, provider, dt.date(2030, 1, 1))['state'], 'fresh')

    def test_unexpected_provider_and_model_shape_fail_closed(self):
        with self.assertRaises(c.CollectionError):
            c.normalize_costs({'daily': [row('claude')]}, 'codex', dt.date(2030, 1, 1))
        entry = row()
        entry['agents'][0]['modelBreakdowns'] = None
        with self.assertRaises(c.CollectionError):
            c.normalize_costs({'daily': [entry]}, 'codex', dt.date(2030, 1, 1))
