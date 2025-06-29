import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thai_herbal_app/features/gacp_certification/data/certification_repository.dart';

class CertificationFlowScreen extends ConsumerStatefulWidget {
  const CertificationFlowScreen({super.key});

  @override
  ConsumerState<CertificationFlowScreen> createState() => _CertificationFlowScreenState();
}

class _CertificationFlowScreenState extends ConsumerState<CertificationFlowScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final applicationState = ref.watch(currentCertificationProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('GACP Certification Process')),
      body: Column(
        children: [
          _buildProgressIndicator(applicationState),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildInitialSubmission(),
                _buildRemoteAssessment(applicationState),
                _buildFieldInspection(applicationState),
                _buildLabSubmission(applicationState),
                _buildCertificateView(applicationState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(AsyncValue<CertificationApplication> state) {
    return state.when(
      data: (app) => Stepper(
        currentStep: _currentStep,
        onStepTapped: (step) => _goToStep(step),
        steps: [
          Step(
            title: const Text('Initial Submission'),
            isActive: _currentStep >= 0,
            state: app.status.index > 0 
                ? StepState.complete 
                : StepState.indexed,
          ),
          Step(
            title: const Text('Remote Assessment'),
            isActive: _currentStep >= 1,
            state: app.status.index > 3 
                ? StepState.complete 
                : StepState.indexed,
          ),
          Step(
            title: const Text('Field Inspection'),
            isActive: _currentStep >= 2,
            state: app.status.index > 9 
                ? StepState.complete 
                : StepState.indexed,
          ),
          Step(
            title: const Text('Lab Submission'),
            isActive: _currentStep >= 3,
            state: app.status.index > 13 
                ? StepState.complete 
                : StepState.indexed,
          ),
          Step(
            title: const Text('Certificate'),
            isActive: _currentStep >= 4,
            state: app.status == CertificationStatus.certificateIssued
                ? StepState.complete 
                : StepState.indexed,
          ),
        ],
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildInitialSubmission() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Submit Documents for GACP Certification',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildDocumentUpload('Farm Registration'),
          _buildDocumentUpload('Land Ownership Proof'),
          _buildDocumentUpload('Cultivation Plan'),
          const SizedBox(height: 20),
          _buildImageUpload('Farm Overview Photos'),
          _buildImageUpload('Cultivation Area Photos'),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _submitApplication,
            child: const Text('Submit Application'),
          ),
        ],
      ),
    );
  }

  void _submitApplication() async {
    // Implementation for submitting application
    await ref.read(certificationRepositoryProvider).submitApplication();
    _goToStep(1);
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.jumpToPage(step);
  }

  // Additional UI components for other steps...
}
