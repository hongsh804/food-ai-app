import 'package:flutter/material.dart';

import '../services/ai_api_service.dart';
import '../services/backend_settings.dart';
import '../services/meal_history_store.dart';
import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _serverController;
  String? _serverStatus;
  bool _serverStatusIsError = false;
  bool _serverActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(
      text: BackendSettings.instance.baseUrl,
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _saveServerAddress() async {
    await _runServerAction(() async {
      final savedAddress = await BackendSettings.instance.save(
        _serverController.text,
      );
      _serverController.text = savedAddress;
      return '백엔드 주소를 저장했습니다.';
    });
  }

  Future<void> _checkServerConnection() async {
    await _runServerAction(() async {
      final savedAddress = await BackendSettings.instance.save(
        _serverController.text,
      );
      _serverController.text = savedAddress;
      final health = await AiApiService.instance.checkHealth();
      final geminiStatus = health.hasGeminiKey
          ? 'Gemini 사용 가능'
          : 'Gemini API 키 없음';
      return '서버 연결 성공 · ${health.model} · $geminiStatus';
    });
  }

  Future<void> _resetServerAddress() async {
    await _runServerAction(() async {
      final defaultAddress = await BackendSettings.instance.reset();
      _serverController.text = defaultAddress;
      return '기본 백엔드 주소로 초기화했습니다.';
    });
  }

  Future<void> _runServerAction(Future<String> Function() action) async {
    if (_serverActionInProgress) return;
    setState(() {
      _serverActionInProgress = true;
      _serverStatus = null;
    });

    try {
      final message = await action();
      if (!mounted) return;
      setState(() {
        _serverStatus = message;
        _serverStatusIsError = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _serverStatus = error.message;
        _serverStatusIsError = true;
      });
    } on AiApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _serverStatus = error.displayMessage;
        _serverStatusIsError = true;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _serverStatus = '백엔드 서버 연결 실패\n$error';
        _serverStatusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _serverActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 118),
        children: [
          const Text(
            '마이',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 22),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '건강한 식사 탐험가',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '꾸준한 기록이 가장 좋은 첫걸음이에요.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: MealHistoryStore.instance,
            builder: (context, _) => AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Count(
                    value: '${MealHistoryStore.instance.records.length}',
                    label: '누적 기록',
                  ),
                  Container(width: 1, height: 38, color: AppColors.border),
                  const _Count(value: 'AI', label: '분석 방식'),
                  Container(width: 1, height: 38, color: AppColors.border),
                  const _Count(value: 'v1.0', label: '앱 버전'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const SectionTitle(title: '앱 정보'),
          const SizedBox(height: 8),
          const AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.shield_outlined,
                  title: '개인정보 보호',
                  subtitle: '사진은 분석 요청에만 사용됩니다.',
                ),
                Divider(height: 1, indent: 58),
                _MenuTile(
                  icon: Icons.health_and_safety_outlined,
                  title: '건강 정보 안내',
                  subtitle: 'AI 결과는 의료 진단이 아닙니다.',
                ),
                Divider(height: 1, indent: 58),
                _MenuTile(
                  icon: Icons.cloud_outlined,
                  title: '분석 서버',
                  subtitle: 'Gemini 연동 환경에서 동작합니다.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionTitle(title: '개발 설정'),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.dns_outlined,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '백엔드 서버 주소',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '현재 주소: ${BackendSettings.instance.baseUrl}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverController,
                  enabled: !_serverActionInProgress,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '백엔드 서버 주소',
                    hintText: 'https://food-ai-app-332i.onrender.com',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _serverActionInProgress
                            ? null
                            : _checkServerConnection,
                        icon: _serverActionInProgress
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering_rounded),
                        label: const Text('서버 연결 확인'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _serverActionInProgress
                            ? null
                            : _saveServerAddress,
                        child: const Text('주소 저장'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: _serverActionInProgress
                            ? null
                            : _resetServerAddress,
                        child: const Text('주소 초기화'),
                      ),
                    ),
                  ],
                ),
                if (_serverStatus != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _serverStatusIsError
                          ? const Color(0xFFFFF1F0)
                          : AppColors.lowSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _serverStatus!,
                      style: TextStyle(
                        color: _serverStatusIsError
                            ? AppColors.high
                            : AppColors.low,
                        fontSize: 11,
                        height: 1.45,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppCard(
            color: Color(0xFFFFFBF0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.medium,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'GlucoLog는 음식 사진을 기반으로 영양 성분과 예상 혈당 상승폭을 제공합니다. 당뇨 치료나 투약 결정에는 반드시 실제 측정기와 의료진 상담을 이용하세요.',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 12,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
