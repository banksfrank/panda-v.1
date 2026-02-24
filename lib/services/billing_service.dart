import 'package:flutter/foundation.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';

enum BillingPlan { monthly, threeMonths, sixMonths, year }

extension BillingPlanX on BillingPlan {
  String get apiValue => switch (this) {
        BillingPlan.monthly => 'monthly',
        BillingPlan.threeMonths => '3months',
        BillingPlan.sixMonths => '6months',
        BillingPlan.year => 'year',
      };

  String get title => switch (this) {
        BillingPlan.monthly => 'Monthly',
        BillingPlan.threeMonths => '3 Months',
        BillingPlan.sixMonths => '6 Months',
        BillingPlan.year => '1 Year',
      };

  String get priceLabel => switch (this) {
        BillingPlan.monthly => '\$12',
        BillingPlan.threeMonths => '\$27',
        BillingPlan.sixMonths => '\$43',
        BillingPlan.year => '\$75',
      };
}

class BillingService {
  const BillingService();

  Future<Uri?> createCheckoutSession({required BillingPlan plan}) async {
    try {
      final supabase = SupabaseBootstrap.client;
      if (supabase == null) {
        debugPrint('BillingService: Supabase not configured; cannot start checkout.');
        return null;
      }

      final origin = kIsWeb ? Uri.base.origin : null;
      final res = await supabase.functions.invoke(
        'create_stripe_checkout_session',
        body: {
          'plan': plan.apiValue,
          if (origin != null) 'returnUrl': '$origin/home',
        },
      );

      final data = res.data;
      if (data is Map && data['url'] is String) {
        final url = (data['url'] as String).trim();
        return url.isEmpty ? null : Uri.tryParse(url);
      }

      debugPrint('BillingService: Unexpected response: ${res.data}');
      return null;
    } catch (e) {
      debugPrint('BillingService.createCheckoutSession failed: $e');
      return null;
    }
  }
}
