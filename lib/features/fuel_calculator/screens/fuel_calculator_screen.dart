import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/fuel_calculator_provider.dart';
import '../widgets/fuel_estimate_card.dart';

class FuelCalculatorScreen extends ConsumerStatefulWidget {
  final String tripId;

  const FuelCalculatorScreen({super.key, required this.tripId});

  @override
  ConsumerState<FuelCalculatorScreen> createState() =>
      _FuelCalculatorScreenState();
}

class _FuelCalculatorScreenState extends ConsumerState<FuelCalculatorScreen> {
  late TextEditingController _efficiencyController;
  late TextEditingController _priceController;
  late EfficiencyUnit _efficiencyUnit;
  late FuelPriceUnit _priceUnit;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(bikeSettingsProvider);
    _efficiencyController = TextEditingController(
      text: settings.efficiency > 0 ? settings.efficiency.toString() : '',
    );
    _priceController = TextEditingController(
      text: settings.fuelPrice > 0 ? settings.fuelPrice.toString() : '',
    );
    _efficiencyUnit = settings.efficiencyUnit;
    _priceUnit = settings.priceUnit;
  }

  @override
  void dispose() {
    _efficiencyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _updateSettings() {
    final settings = BikeSettings(
      efficiency: double.tryParse(_efficiencyController.text) ?? 0,
      efficiencyUnit: _efficiencyUnit,
      fuelPrice: double.tryParse(_priceController.text) ?? 0,
      priceUnit: _priceUnit,
    );
    ref.read(bikeSettingsProvider.notifier).update(settings);
  }

  Future<void> _saveSettings() async {
    _updateSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bike settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimate = ref.watch(fuelEstimateProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Fuel Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          // Input card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bike Settings', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppDimensions.paddingMD),

                  // Fuel efficiency
                  Text('Fuel Efficiency', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppDimensions.paddingSM),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _efficiencyController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                          ),
                          onChanged: (_) => _updateSettings(),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.paddingSM),
                      SegmentedButton<EfficiencyUnit>(
                        segments: const [
                          ButtonSegment(
                              value: EfficiencyUnit.kmpl, label: Text('km/L')),
                          ButtonSegment(
                              value: EfficiencyUnit.mpg, label: Text('MPG')),
                        ],
                        selected: {_efficiencyUnit},
                        onSelectionChanged: (set) {
                          setState(() => _efficiencyUnit = set.first);
                          _updateSettings();
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.paddingMD),

                  // Fuel price
                  Text('Fuel Price', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppDimensions.paddingSM),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            prefixText: '\u20B1 ',
                            hintText: '0',
                            isDense: true,
                          ),
                          onChanged: (_) => _updateSettings(),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.paddingSM),
                      SegmentedButton<FuelPriceUnit>(
                        segments: const [
                          ButtonSegment(
                              value: FuelPriceUnit.liter,
                              label: Text('per L')),
                          ButtonSegment(
                              value: FuelPriceUnit.gallon,
                              label: Text('per gal')),
                        ],
                        selected: {_priceUnit},
                        onSelectionChanged: (set) {
                          setState(() => _priceUnit = set.first);
                          _updateSettings();
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.paddingMD),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Settings'),
                      onPressed: _saveSettings,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.paddingMD),

          // Results
          if (estimate != null)
            FuelEstimateCard(estimate: estimate)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingLG),
                child: Column(
                  children: [
                    Icon(Icons.local_gas_station,
                        size: 48, color: AppColors.textHint),
                    const SizedBox(height: AppDimensions.paddingSM),
                    Text(
                      'Enter bike settings and add at least 2 stops with locations to see fuel estimates.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
