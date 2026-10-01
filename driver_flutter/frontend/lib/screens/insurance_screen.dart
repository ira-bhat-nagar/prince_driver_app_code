import 'package:flutter/material.dart';
import '../core/app_toast.dart';
import '../core/theme.dart';
import '../models/insurance_models.dart';
import '../services/insurance_service.dart';

class InsuranceScreen extends StatefulWidget {
  final VoidCallback? onBackTap;
  const InsuranceScreen({super.key, this.onBackTap});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  InsurancePolicy? _policy;
  List<InsuranceClaim> _claims = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _policy = InsurancePolicy(
        policyNumber: 'POL-12345678',
        insurerName: 'GoRush Secure Insurance',
        uin: 'UIN-987654',
        status: 'Active',
        policyStartDate: DateTime.now().subtract(const Duration(days: 30)),
        policyEndDate: DateTime.now().add(const Duration(days: 335)),
        coverage: {
            'personalAccident': '₹5,00,000',
            'hospitalization': '₹1,00,000',
            'opd': '₹5,000',
        },
        exclusions: ['Drunk driving', 'Intentional self-injury', 'Unlicensed driving'],
      );
      _claims = [];
      _loading = false;
      _error = null;
    });

    try {
      final results = await Future.wait([
        InsuranceService.instance.getPolicy(),
        InsuranceService.instance.getClaims(),
      ]);
      if (mounted) {
        setState(() {
          _policy = results[0] as InsurancePolicy?;
          _claims = results[1] as List<InsuranceClaim>;
        });
      }
    } catch (_) {}
  }

  String _coverage(String key) {
    final value = _policy?.coverage[key];
    return value == null || value.toString().trim().isEmpty
        ? 'Coverage as per applicable policy'
        : value.toString();
  }

  String _coverageValue(String title, String key) {
    final configured = _policy?.coverage[key]?.toString().trim();
    if (configured != null && configured.isNotEmpty) return configured;
    switch (title) {
      case 'Personal Accident':
        return '₹5,00,000 accidental death benefit only';
      case 'Hospitalization':
        return '₹1,00,000 medical / hospitalization benefit';
      case 'OPD Treatment':
        return '₹5,000 OPD benefit';
      case 'Temporary Disability':
        return 'As per applicable policy';
      default:
        return 'Available where included in the applicable policy';
    }
  }

  String _date(DateTime? value) => value == null
      ? 'Not available'
      : '${value.day}/${value.month}/${value.year}';

  String _coverageDescription(String title) {
    switch (title) {
      case 'Personal Accident':
        return 'The ₹5,00,000 benefit is for accidental death only. It is not medical treatment coverage. Separate benefits may apply for hospitalization and OPD treatment.';
      case 'Hospitalization':
        return 'The separate ₹1,00,000 benefit may consider eligible accident-related medical and hospitalization expenses when treatment is medically required.';
      case 'OPD Treatment':
        return 'The separate ₹5,000 benefit may consider eligible accident-related outpatient consultation and treatment without hospitalization.';
      case 'Temporary Disability':
        return 'Temporary Disability means a covered accident temporarily prevents normal driving work, subject to medical evidence and the policy definition.';
      default:
        return 'Emergency, accident, claim, medical, roadside and safety assistance is available only where included in the applicable policy or GoRush service package.';
    }
  }

  String _coverageHeading(String title) => title == 'Personal Accident'
      ? 'Accidental Death Coverage'
      : title == 'Hospitalization'
          ? 'Medical / Hospitalization Coverage'
          : title == 'OPD Treatment'
              ? 'OPD Treatment Coverage'
              : 'Benefit shown';

  List<Widget> _coverageSections(String title) {
    final common = <Widget>[
      _infoSection('Important limitations', [
        'Coverage is subject to policy terms, eligibility, exclusions, required documents, policy validity and claim verification.',
        'The stated limit is not automatically payable for every accident, bill, visit or claim.',
        'Only eligible and admissible expenses or benefits can be considered by the insurer.',
      ]),
      _infoSection('Important information', [
        'Coverage, eligibility, exclusions, claim amount and settlement are subject to the applicable insurance policy terms and conditions.',
      ]),
    ];
    switch (title) {
      case 'Personal Accident':
        return [
          _infoSection('Personal Accident details', [
            'Insurance type: Personal Accident Insurance',
            'Accidental death coverage: ₹5,00,000',
            'Coverage / policy period: ${_date(_policy?.policyStartDate)} – ${_date(_policy?.policyEndDate)}',
            'Policy status: ${_policy?.status ?? 'Not available'}',
            'Insurance company: ${_policy?.insurerName.isNotEmpty == true ? _policy!.insurerName : 'Not available'}',
            'Policy number: ${_policy?.policyNumber.isNotEmpty == true ? _policy!.policyNumber : 'Not available'}',
            'Premium amount: As per applicable policy',
            'Start date: ${_date(_policy?.policyStartDate)}',
            'Expiry / renewal date: ${_date(_policy?.policyEndDate)}',
            'Nominee information: Refer to the enrolled policy records',
            'Claim status: See My Claims',
            'Claim support: Use Raise a Claim or configured support',
          ]),
          _infoSection('What is covered', [
            'Accidental death may be covered up to the applicable ₹5,00,000 benefit when policy conditions are satisfied.',
            'Medical treatment is not part of this ₹5,00,000 death benefit.',
            'Separate medical / hospitalization coverage: ₹1,00,000.',
            'Separate OPD coverage: ₹5,000.',
          ]),
          _infoSection('Claim process', [
            '1. Report the accident.',
            '2. Submit required claim documents.',
            '3. The insurer / GoRush team verifies the claim.',
            '4. The insurer assesses it under the applicable policy.',
            '5. An approved eligible claim is processed.',
          ]),
          _infoSection('Required documents may include', [
            'Driver ID/KYC and policy details',
            'Accident details and medical/hospital documents where applicable',
            'Medical reports and FIR/police report where required',
            'Death certificate for accidental-death claims',
            'Nominee/legal-heir documents where required',
          ]),
          ...common,
        ];
      case 'Hospitalization':
        return [
          _infoSection('What this benefit means', [
            'Eligible accident/injury medical expenses may be considered when hospitalization and treatment are medically required.',
            'The final admissible amount depends on policy terms, limits, exclusions, eligibility and claim assessment.',
          ]),
          _infoSection('Expenses that may be covered', [
            'Hospital room and boarding, nursing, doctor, surgeon and specialist charges',
            'Operation/theatre charges, medicines and prescribed drugs',
            'Diagnostic tests, investigations, X-ray and emergency treatment',
            'Other eligible hospitalization expenses allowed by the policy',
          ]),
          _infoSection('Before and after hospitalization', [
            'Eligible pre-hospitalization expenses related to the same admissible injury may be considered within the policy period and limits.',
            'Eligible post-hospitalization expenses related to the same admissible injury may be considered subject to policy terms and limits.',
          ]),
          _infoSection('Cashless / reimbursement', [
            'Where available, eligible treatment may use a cashless facility at an eligible network hospital.',
            'If cashless treatment is unavailable, eligible expenses may be considered for reimbursement through the required claim process.',
            'Cashless treatment is not promised at every hospital.',
          ]),
          _infoSection('Claim process', [
            '1. Report the accident or injury.',
            '2. Seek treatment or hospitalization when required.',
            '3. Inform insurer / GoRush support within the applicable timeline.',
            '4. Submit medical and claim documents.',
            '5. The insurer reviews and assesses the claim.',
            '6. An eligible amount is processed according to the policy.',
          ]),
          _infoSection('Documents that may be required', [
            'Driver ID/KYC and policy/certificate details',
            'Admission documents, discharge summary and doctor prescriptions',
            'Medical, diagnostic, hospital, pharmacy and medicine bills',
            'Accident/FIR/police report where required',
            'Any document requested by the insurer',
          ]),
          _infoSection('Difference between benefits', [
            'Personal Accident: ₹5,00,000 — accidental death benefit.',
            'Hospitalization: ₹1,00,000 — eligible hospitalization/medical expenses.',
            'OPD: ₹5,000 — eligible outpatient expenses.',
          ]),
          ...common,
        ];
      case 'OPD Treatment':
        return [
          _infoSection('What OPD means', [
            'Eligible accident-related outpatient consultation and treatment may be considered without hospitalization, subject to policy terms, limits, eligibility and documents.',
          ]),
          _infoSection('OPD expenses that may be covered', [
            'Doctor or specialist consultation fees',
            'Prescribed medicines, diagnostic tests and blood tests',
            'X-rays and required investigations',
            'Minor accident-related treatment, dressing and wound treatment',
            'Follow-up consultation and other eligible outpatient treatment',
          ]),
          _infoSection('OPD vs hospitalization', [
            'OPD Treatment: ₹5,000 — eligible outpatient treatment where hospitalization is not required.',
            'Hospitalization: ₹1,00,000 — eligible hospitalization/medical expenses when hospitalization is required.',
            'Personal Accident: ₹5,00,000 — accidental death benefit only.',
          ]),
          _infoSection('Example (not a guaranteed payout)', [
            'If eligible accident-related OPD treatment costs ₹2,000, the eligible amount may be considered under the OPD benefit.',
            'If eligible OPD expenses are ₹6,000, the maximum cannot exceed the applicable ₹5,000 limit, subject to assessment.',
          ]),
          _infoSection('Claim process', [
            '1. Report the accident if required.',
            '2. Visit an eligible doctor or medical facility.',
            '3. Keep prescriptions, reports and original bills.',
            '4. Submit required documents.',
            '5. The insurer reviews and processes the eligible amount.',
          ]),
          _infoSection('Documents that may be required', [
            'Driver ID/KYC and policy/certificate details',
            'Doctor prescription, consultation receipt and medical reports',
            'Diagnostic, medicine/pharmacy and treatment bills',
            'Accident details and any additional document requested',
          ]),
          ...common,
        ];
      case 'Temporary Disability':
        return [
          _infoSection('Meaning and eligibility', [
            'Temporary Disability is a temporary medical condition caused by a covered accident that prevents normal driving/work duties for a defined period.',
            'Eligibility requires a covered accident, active policy, medical inability to work, qualified medical evidence and the policy definition being met.',
          ]),
          _infoSection('Benefit and duration', [
            'Temporary Disability Benefit: As per applicable policy.',
            'The benefit may depend on the disability period, limits and eligibility.',
            'It is payable only for the eligible period defined by the policy and may have waiting periods or maximum duration limits.',
          ]),
          _infoSection('Medical evidence may include', [
            'Doctor certificate, medical reports, diagnosis and treatment records',
            'Hospital/clinic records, prescriptions and fitness/unfitness-to-work certificate',
            'Any additional document required by the insurer',
          ]),
          _infoSection('How the claim works', [
            '1. Accident occurs and medical treatment is received.',
            '2. Doctor confirms temporary inability to work where applicable.',
            '3. Report the claim and submit medical documents.',
            '4. The insurer verifies the accident and evidence.',
            '5. Eligibility and disability period are assessed.',
            '6. Approved benefit is processed under the policy.',
          ]),
          _infoSection('Benefits comparison', [
            'Personal Accident: ₹5,00,000 — accidental death benefit.',
            'Hospitalization: ₹1,00,000 — eligible medical expenses.',
            'OPD: ₹5,000 — eligible outpatient treatment.',
            'Temporary Disability: As per applicable policy — covered temporary inability to work.',
          ]),
          ...common,
        ];
      default:
        return [
          _infoSection('Benefit categories', [
            'Emergency assistance',
            'Accident support',
            'Claim assistance',
            'Medical assistance',
            'Roadside / vehicle assistance',
            'Customer / safety support',
          ]),
          _infoSection('What to do after an accident', [
            '1. Ensure safety and contact emergency services when required.',
            '2. Inform GoRush Safety / Support.',
            '3. Seek medical assistance when required.',
            '4. Preserve accident, medical and vehicle documents.',
            '5. Report the claim within the applicable timeline.',
            '6. Submit required documents and await insurer assessment.',
          ]),
          _infoSection('Important information', [
            'Other benefits are available only when included in the applicable policy or GoRush service package.',
            'Emergency contact numbers are configurable through approved support settings; use the configured GoRush Safety / Insurance Support option.',
          ]),
          ...common,
        ];
    }
  }

  Widget _infoSection(String title, List<String> lines) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $line', style: const TextStyle(height: 1.35)),
              )),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5ED),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: QuickServeColors.textDark),
          onPressed: widget.onBackTap ?? () => Navigator.maybePop(context),
        ),
        title: const Text('GoRush Ride Insurance',
            style: TextStyle(
                color: QuickServeColors.textDark, fontWeight: FontWeight.bold)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 900 ? 920 : 680),
            child: Column(
              children: [
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF0D2418),
                  unselectedLabelColor: const Color(0xFF718096),
                  indicatorColor: QuickServeColors.primaryBlue,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: EdgeInsets.zero,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'My Insurance'),
                    Tab(text: 'Claims'),
                    Tab(text: 'Help & Terms'),
                  ],
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _errorState()
                          : TabBarView(
                              controller: _tabs,
                              children: [
                                _overview(),
                                _myInsurance(),
                                _claimsView(),
                                _helpView(),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shield_outlined,
                size: 54, color: Color(0xFF718096)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );

  Widget _overview() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _heroCard(),
          const SizedBox(height: 16),
          const Text('What may be covered',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _coverageCard(
                  'Personal Accident',
                  _coverageValue('Personal Accident', 'personalAccident'),
                  Icons.health_and_safety_outlined),
              _coverageCard(
                  'Hospitalization',
                  _coverageValue('Hospitalization', 'hospitalization'),
                  Icons.local_hospital_outlined),
              _coverageCard(
                  'OPD Treatment',
                  _coverageValue('OPD Treatment', 'opd'),
                  Icons.medical_services_outlined),
              _coverageCard(
                  'Temporary Disability',
                  _coverageValue('Temporary Disability', 'disability'),
                  Icons.accessibility_new),
              _coverageCard(
                  'Other Benefits',
                  _coverageValue('Other Benefits', 'otherBenefits'),
                  Icons.support_agent),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard('Who can use this benefit?', [
            'Eligible GoRush customers and drivers covered under the applicable insurance program',
            'Users associated with an eligible GoRush ride or insured event',
            'Users whose ride or incident meets the applicable coverage and eligibility conditions',
            'Users who satisfy the policy, documentation and applicable terms',
            'Coverage is available only for benefits included in the applicable insurance policy',
            'Eligibility may vary by ride type, incident and insurance benefit',
          ]),
          const SizedBox(height: 12),
          _sectionCard('When coverage may apply', [
            'Ride Booking → Eligible ride identified → Coverage eligibility checked',
            'Ride Starts → Applicable ride-related coverage becomes active where provided by the policy',
            'Accident / Insured Event → Incident occurs during an eligible coverage period',
            'Report Incident → User submits required incident and claim information',
            'Claim Submission → Required documents and supporting evidence are provided',
            'Insurer Review → Licensed insurance partner verifies eligibility, policy terms and documents',
            'Claim Assessment → Coverage, limits, exclusions and admissible expenses are evaluated',
            'Claim Decision → Claim is approved, partially approved or rejected under the policy',
            'Settlement → Approved eligible claim amount or benefit is processed under policy terms',
          ]),
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              'Coverage is subject to policy eligibility, applicable limits, exclusions, documentation requirements and the terms of the insurance policy issued by the licensed insurance partner.',
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
            ),
          ),
          _disclaimer(),
        ],
      );

  Widget _heroCard() => Card(
        elevation: 0,
        color: const Color(0xFF0D2418),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_rounded,
                color: Color(0xFF9BCB65), size: 58),
            const SizedBox(height: 10),
            const Text('Your ride. Your safety. Extra protection.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Eligible rides may include accident-related insurance benefits provided through GoRush’s partnered licensed insurer.',
              style:
                  TextStyle(color: Colors.white.withOpacity(.8), height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              ElevatedButton(
                onPressed: () => _tabs.animateTo(1),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9BCB65),
                    foregroundColor: const Color(0xFF0D2418)),
                child: const Text('View My Coverage'),
              ),
              OutlinedButton(
                onPressed: _showInsuranceOverview,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('How Insurance Works'),
              ),
            ]),
          ]),
        ),
      );

  Widget _myInsurance() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _sectionCard('My Insurance', [
            'Coverage status: ${_policy?.status ?? 'Not available'}',
            'Policy number: ${_policy?.policyNumber.isNotEmpty == true ? _policy!.policyNumber : 'Not available'}',
            'Insurer: ${_policy?.insurerName.isNotEmpty == true ? _policy!.insurerName : 'Not available'}',
            'Policy/UIN: ${_policy?.uin.isNotEmpty == true ? _policy!.uin : 'Not available'}',
            'Policy period: ${_date(_policy?.policyStartDate)} – ${_date(_policy?.policyEndDate)}',
            'Coverage: As per applicable policy',
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            ElevatedButton.icon(
                onPressed: _showPolicyDetails,
                icon: const Icon(Icons.description_outlined),
                label: const Text('View Policy')),
            OutlinedButton.icon(
                onPressed: () => _tabs.animateTo(2),
                icon: const Icon(Icons.file_present_outlined),
                label: const Text('Raise a Claim')),
          ]),
          _disclaimer(),
        ],
      );

  Widget _claimsView() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(children: [
            const Expanded(
                child: Text('My Claims',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            ElevatedButton.icon(
                onPressed: _openClaimFlow,
                icon: const Icon(Icons.add),
                label: const Text('Raise Claim')),
          ]),
          const SizedBox(height: 12),
          if (_claims.isEmpty)
            _sectionCard('No claims yet',
                ['Submit a claim only for an eligible insured event.'])
          else
            ..._claims.map(_claimCard),
        ],
      );

  Widget _claimCard(InsuranceClaim claim) => Card(
        elevation: 0,
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.shield_outlined)),
          title: Text(claim.claimNumber.isEmpty ? 'Claim' : claim.claimNumber),
          subtitle: Text('${claim.claimType} • Ride ${claim.rideId}'),
          trailing: Text(claim.status),
          onTap: () => _showClaimDetails(claim),
        ),
      );

  Widget _helpView() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Help & FAQ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          for (final item in _faqAnswers.entries)
            ExpansionTile(
              title: Text(item.key),
              children: [
                Padding(
                    padding: const EdgeInsets.all(12), child: Text(item.value))
              ],
            ),
          _sectionCard('Insurance Terms & Conditions', [
            'GoRush facilitates access to eligible insurance benefits through a licensed insurance partner and is not the insurer unless expressly stated otherwise.',
            'Coverage eligibility, limits, exclusions, claim requirements and settlement are governed by the applicable policy wording.',
          ]),
          _disclaimer(),
        ],
      );

  Widget _sectionCard(String title, List<String> lines) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 8),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $line', style: const TextStyle(height: 1.35)),
                )),
          ]),
        ),
      );

  Widget _coverageCard(String title, String value, IconData icon) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCoverageDetails(title, value, icon),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: const Color(0xFF376B3A)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Expanded(
                  child: Text(value, style: const TextStyle(fontSize: 11))),
              const Align(
                alignment: Alignment.bottomRight,
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Color(0xFF376B3A)),
              ),
            ]),
          ),
        ),
      );

  Map<String, String> get _faqAnswers => {
        'What is GoRush Ride Insurance?':
            'GoRush facilitates access to eligible accident-related benefits through a licensed insurance partner. GoRush is not the insurer. Coverage is subject to the applicable policy.',
        'Who provides the insurance?':
            'The applicable licensed insurance partner provides and assesses the insurance benefit. Partner and policy details are shown only when approved data is configured.',
        'Is every ride covered?':
            'No. Eligibility depends on the ride, user, coverage activation and the applicable policy requirements.',
        'When does coverage start?':
            'Coverage activation and duration are subject to the applicable policy wording and the ride eligibility decision.',
        'What is covered?':
            'Benefits may include accidental injury, eligible hospitalization, OPD treatment or disability only where listed in the approved policy.',
        'What is not covered?':
            'Policy exclusions, ineligible events, fraudulent claims, events outside policy scope and claims that do not meet applicable requirements are not covered.',
        'How do I raise a claim?':
            'Open My Insurance, select Raise Claim, enter the incident and ride details, upload the requested documents and submit the claim for insurer review.',
        'What documents are required?':
            'Documents vary by claim type and may include identity proof, medical records, hospital bills, discharge summary, incident report or police/FIR documents where applicable.',
        'Who assesses my claim?':
            'The licensed insurance partner reviews the claim, documents and eligibility according to the applicable policy.',
        'How can I track my claim?':
            'Open the Claims tab to view the claim number and its latest status. Status updates depend on insurer review.',
        'What if my claim is rejected?':
            'The insurer provides the applicable decision and reason. Review the policy wording and use the configured support or grievance channel.',
        'How can I contact the insurer?':
            'Use the insurer contact details published in the approved policy documents. Placeholder contact details are not shown.',
        'How can I raise a grievance?':
            'Follow the grievance process stated in the approved policy and insurer documentation.',
      };

  Future<void> _showCoverageDetails(
      String title, String value, IconData icon) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, color: const Color(0xFF376B3A), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 16),
                  Text(_coverageHeading(title),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value),
                  const SizedBox(height: 14),
                  Text(_coverageDescription(title),
                      style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 12),
                  ..._coverageSections(title),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Close')),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showPolicyDetails() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.policy_outlined, color: Color(0xFF376B3A)),
          SizedBox(width: 10),
          Expanded(child: Text('Policy Details')),
        ]),
        content: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _policyRow('Insurer', _policy?.insurerName),
            _policyRow('Policy number', _policy?.policyNumber),
            _policyRow('UIN', _policy?.uin),
            _policyRow('Policy period',
                '${_date(_policy?.policyStartDate)} – ${_date(_policy?.policyEndDate)}'),
            const SizedBox(height: 12),
            const Text('Policy overview',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'GoRush facilitates access to eligible insurance benefits through a licensed insurance partner. GoRush is not itself the insurer.'),
            const SizedBox(height: 12),
            const Text('Coverage',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                'Personal Accident: ${_coverage('personalAccident')}\nHospitalization: ${_coverage('hospitalization')}\nOPD Treatment: ${_coverage('opd')}\nDisability: ${_coverage('disability')}\nOther Benefits: ${_coverage('otherBenefits')}'),
            const SizedBox(height: 12),
            const Text('Important exclusions',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_policy?.exclusions.isNotEmpty == true
                ? _policy!.exclusions.map((item) => '• $item').join('\n')
                : 'Please refer to the applicable policy wording for complete exclusions.'),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showInsuranceOverview() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('How Insurance Works',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            _infoSection('Insurance status', [
              'Status: ${_policy?.status ?? 'Not available'}',
              'Coverage period: ${_date(_policy?.policyStartDate)} – ${_date(_policy?.policyEndDate)}',
              'Policy number: ${_policy?.policyNumber.isNotEmpty == true ? _policy!.policyNumber : 'Not available'}',
              'Insurance company: ${_policy?.insurerName.isNotEmpty == true ? _policy!.insurerName : 'Not available'}',
              'Premium: As per applicable policy',
            ]),
            _infoSection('My coverage summary', [
              'Personal Accident: ₹5,00,000 — accidental death only.',
              'Hospitalization: ₹1,00,000 — eligible medical/hospitalization expenses.',
              'OPD: ₹5,000 — eligible outpatient expenses.',
              'Temporary Disability: As per applicable policy.',
              'Other benefits: Only where included in the applicable policy or service package.',
            ]),
            _infoSection('How it works', [
              'Different benefits have separate limits and conditions.',
              'Coverage activation and duration depend on the eligible ride and applicable policy.',
              'Claims are verified and assessed by the licensed insurance partner.',
            ]),
            _infoSection('Important information', [
              'Coverage, eligibility, exclusions, limits, waiting periods, claim assessment and settlement are subject to the applicable insurance policy terms and conditions.',
            ]),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close')),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _policyRow(String label, String? value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 105,
              child:
                  Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Expanded(
              child: Text(
                  value == null || value.isEmpty ? 'Not available' : value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _disclaimer() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'Insurance benefits, eligibility, coverage limits, exclusions, claim requirements and settlement are governed by the applicable insurance policy issued by the licensed insurance partner. GoRush facilitates access to eligible insurance benefits and is not the insurer unless expressly stated otherwise.',
          style:
              TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.4),
        ),
      );

  Future<void> _openClaimFlow() async {
    final typeController = TextEditingController(text: 'Accident');
    final rideController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final claim = await showDialog<InsuranceClaim?>(
      context: context,
      builder: (dialogContext) {
        var submitting = false;
        String? validationError;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Raise a Claim'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: typeController.text,
                  items: const [
                    'Accident',
                    'Hospitalization',
                    'Injury',
                    'Other eligible event'
                  ]
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: submitting
                      ? null
                      : (value) => typeController.text = value ?? 'Accident',
                  decoration: const InputDecoration(labelText: 'Incident type'),
                ),
                TextField(
                    controller: rideController,
                    enabled: !submitting,
                    decoration: const InputDecoration(labelText: 'Ride ID')),
                TextField(
                    controller: locationController,
                    enabled: !submitting,
                    decoration:
                        const InputDecoration(labelText: 'Incident location')),
                TextField(
                    controller: descriptionController,
                    enabled: !submitting,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                if (validationError != null) ...[
                  const SizedBox(height: 10),
                  Text(validationError!,
                      style: const TextStyle(color: Colors.red)),
                ],
              ]),
            ),
            actions: [
              TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final rideId = rideController.text.trim();
                        final location = locationController.text.trim();
                        final description = descriptionController.text.trim();
                        final claimType = typeController.text.trim();
                        if (claimType.isEmpty ||
                            rideId.isEmpty ||
                            location.isEmpty ||
                            description.isEmpty) {
                          setDialogState(() => validationError =
                              'Incident type, Ride ID, location and description are required.');
                          return;
                        }
                        setDialogState(() {
                          submitting = true;
                          validationError = null;
                        });
                        // Capture time BEFORE the async gap to avoid using
                        // BuildContext across an await boundary (causes black screen)
                        final incidentTime = TimeOfDay.now().format(ctx);
                        try {
                          final result =
                              await InsuranceService.instance.submitClaim({
                            'claimType': claimType,
                            'rideId': rideId,
                            'incidentLocation': location,
                            'description': description,
                            'incidentDate': DateTime.now().toIso8601String(),
                            'incidentTime': incidentTime,
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, result);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              submitting = false;
                              validationError =
                                  'Unable to submit claim. Please try again.';
                            });
                          }
                          debugPrint(
                              'Insurance claim submission failed: $error');
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Claim'),
              ),
            ],
          ),
        );
      },
    );
    // Dispose controllers AFTER the dialog has fully closed
    typeController.dispose();
    rideController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    // Guard: if cancelled (null) or widget unmounted, do nothing
    if (claim == null || !mounted) return;
    setState(() => _claims = [claim, ..._claims]);
    AppToast.success(context,
        'Claim submitted successfully. ID: ${claim.claimNumber.isEmpty ? claim.id : claim.claimNumber}');
  }

  Future<void> _showClaimDetails(InsuranceClaim claim) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            claim.claimNumber.isEmpty ? 'Claim Details' : claim.claimNumber),
        content: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _policyRow('Status', claim.status),
            _policyRow('Incident type', claim.claimType),
            _policyRow('Ride ID', claim.rideId),
            _policyRow('Incident date', _date(claim.incidentDate)),
            _policyRow('Location', claim.incidentLocation),
            const SizedBox(height: 8),
            const Text('Description',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(claim.description),
            const SizedBox(height: 12),
            const Text(
                'Claim assessment and settlement are subject to the applicable policy.'),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }
}
