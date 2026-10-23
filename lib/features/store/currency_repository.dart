import 'package:supabase_flutter/supabase_flutter.dart';

class Currency {
  const Currency(
    this.code,
    this.name,
    this.country, [
    this.symbol,
    this.nameId,
  ]);
  final String code;
  final String name;
  final String country;
  final String? symbol;
  final String? nameId;

  /// Nama untuk ditampilkan (Indonesia bila ada).
  String get label => nameId ?? name;
}

/// Salinan bawaan bila daftar dari database gagal dimuat.
/// Samakan dengan isi tabel public.currencies.
const kFallbackCurrencies = <Currency>[
  Currency('USD', 'US Dollar', 'United States', r'$', 'Dolar Amerika Serikat'),
  Currency('MYR', 'Malaysian Ringgit', 'Malaysia', 'RM', 'Ringgit Malaysia'),
  Currency('SGD', 'Singapore Dollar', 'Singapore', r'S$', 'Dolar Singapura'),
  Currency('THB', 'Thai Baht', 'Thailand', null, 'Baht Thailand'),
  Currency('PHP', 'Philippine Peso', 'Philippines', null, 'Peso Filipina'),
  Currency('VND', 'Vietnamese Dong', 'Vietnam', null, 'Dong Vietnam'),
  Currency('BND', 'Brunei Dollar', 'Brunei', r'B$', 'Dolar Brunei'),
  Currency('KHR', 'Cambodian Riel', 'Cambodia', null, 'Riel Kamboja'),
  Currency('LAK', 'Lao Kip', 'Laos', null, 'Kip Laos'),
  Currency('MMK', 'Myanmar Kyat', 'Myanmar', null, 'Kyat Myanmar'),
  Currency('JPY', 'Japanese Yen', 'Japan', '¥', 'Yen Jepang'),
  Currency('KRW', 'South Korean Won', 'South Korea', null, 'Won Korea Selatan'),
  Currency('CNY', 'Chinese Yuan', 'China', '¥', 'Yuan Tiongkok'),
  Currency('INR', 'Indian Rupee', 'India', null, 'Rupee India'),
  Currency('AUD', 'Australian Dollar', 'Australia', r'A$', 'Dolar Australia'),
  Currency('EUR', 'Euro', 'Eurozone', '€', 'Euro'),
  Currency(
    'GBP',
    'Pound Sterling',
    'United Kingdom',
    '£',
    'Pound Sterling Inggris',
  ),
  Currency('SAR', 'Saudi Riyal', 'Saudi Arabia', null, 'Riyal Arab Saudi'),
  Currency(
    'AED',
    'UAE Dirham',
    'United Arab Emirates',
    null,
    'Dirham Uni Emirat Arab',
  ),
  Currency('EGP', 'Egyptian Pound', 'Egypt', null, 'Pound Mesir'),
  Currency('PKR', 'Pakistani Rupee', 'Pakistan', null, 'Rupee Pakistan'),
  Currency('BDT', 'Bangladeshi Taka', 'Bangladesh', null, 'Taka Bangladesh'),
  Currency('TRY', 'Turkish Lira', 'Turkey', null, 'Lira Turki'),
  Currency(
    'PGK',
    'Papua New Guinean Kina',
    'Papua New Guinea',
    null,
    'Kina Papua Nugini',
  ),
];

class CurrencyRepository {
  CurrencyRepository._();
  static final instance = CurrencyRepository._();

  List<Currency>? _cache;

  /// Dari database; bila gagal memakai [kFallbackCurrencies] (tidak di-cache,
  /// jadi pembukaan berikutnya mencoba database lagi).
  Future<List<Currency>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final rows = await Supabase.instance.client
          .from('currencies')
          .select('code, name, name_id, country, symbol')
          .eq('is_active', true)
          .order('sort_order')
          .order('code');
      final list = [
        for (final r in rows)
          Currency(
            r['code'] as String,
            r['name'] as String,
            r['country'] as String,
            r['symbol'] as String?,
            r['name_id'] as String?,
          ),
      ];
      if (list.isNotEmpty) {
        _cache = list;
        return list;
      }
    } catch (_) {}
    return kFallbackCurrencies;
  }

  Currency? lookup(String code) {
    for (final c in _cache ?? kFallbackCurrencies) {
      if (c.code == code) return c;
    }
    return null;
  }
}
