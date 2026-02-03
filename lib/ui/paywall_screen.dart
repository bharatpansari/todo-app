import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/pro_service.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onUpgradeComplete;

  const PaywallScreen({super.key, this.onUpgradeComplete});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final ProService _proService = ProService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Close Button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const SizedBox(height: 40),
                   Icon(
                     LucideIcons.crown,
                     size: 56,
                     color: Colors.amber.shade700,
                   ),
                   const SizedBox(height: 20),
                   Text(
                     "Upgrade to Pro",
                     style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     "Unlock the full power of Talkative Todo",
                     textAlign: TextAlign.center,
                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                       color: Theme.of(context).hintColor,
                     ),
                   ),
                   const SizedBox(height: 32),
                   
                   // Features List
                   _buildFeatureRow(context, "Unlimited Projects", "5 Projects"),
                   _buildFeatureRow(context, "Unlimited Labels", "10 Labels"),
                   _buildFeatureRow(context, "Unlimited Reminders", "1 per Task"),
                   _buildFeatureRow(context, "Board & Calendar Views", "List Only"),
                   _buildFeatureRow(context, "Voice-to-Task", "Locked"),
                   _buildFeatureRow(context, "Project Templates", "Locked"),

                   const Spacer(),
                   
                   // Price Card
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                     margin: const EdgeInsets.only(bottom: 16),
                     decoration: BoxDecoration(
                       color: Colors.amber.shade50,
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.amber.shade200),
                     ),
                     child: Column(
                       children: [
                         Text(
                           "\$9.99",
                           style: TextStyle(
                             fontSize: 28,
                             fontWeight: FontWeight.bold,
                             color: Colors.amber.shade800,
                           ),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           "Lifetime Access • One-time Payment",
                           style: TextStyle(
                             fontSize: 13,
                             color: Colors.amber.shade700,
                           ),
                         ),
                       ],
                     ),
                   ),
                   
                   // Upgrade Button
                   SizedBox(
                     width: double.infinity,
                     height: 52,
                     child: FilledButton.icon(
                       onPressed: _isLoading ? null : _handlePurchase,
                       style: FilledButton.styleFrom(
                         backgroundColor: Colors.amber.shade700,
                         foregroundColor: Colors.white,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                       ),
                       icon: _isLoading 
                           ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                           : const Icon(LucideIcons.sparkles, size: 20),
                       label: Text(
                         _isLoading ? "Processing..." : "Upgrade to Pro",
                         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                       ),
                     ),
                   ),
                   const SizedBox(height: 16),
                   
                   TextButton(
                     onPressed: _restorePurchase,
                     child: const Text("Restore Purchase"),
                   ),
                   const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, String proFeature, String freeFeature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, size: 14, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              proFeature, 
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ),
          Text(
            freeFeature,
            style: TextStyle(
              color: Theme.of(context).disabledColor,
              decoration: TextDecoration.lineThrough,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    await _proService.purchasePro();
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      widget.onUpgradeComplete?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Pro!')),
      );
    }
  }

  Future<void> _restorePurchase() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    await _proService.restorePurchases();
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
      widget.onUpgradeComplete?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchases Restored')),
      );
    }
  }
}
