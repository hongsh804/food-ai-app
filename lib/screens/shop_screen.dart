import 'package:flutter/material.dart';

import '../services/membership_store.dart';
import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 118),
        children: [
          const Text(
            'LOW42 쇼핑',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'LOW42 제품과 매장 혜택을 한눈에 확인하세요.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3212B9A1),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '맛있는 저당 라이프',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'LOW42 제품을\n매장에서 먼저 만나보세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 17),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                  ),
                  onPressed: () => _showPreparing(context),
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text(
                    '매장 상품 보기',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionTitle(title: '추천 상품'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: .78,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _ProductCard(
                icon: Icons.bakery_dining_rounded,
                name: 'LOW42 저당 밀가루',
                detail: '베이킹과 요리에 가볍게',
                badge: '대표 상품',
                onTap: () => _showPreparing(context),
              ),
              _ProductCard(
                icon: Icons.ramen_dining_rounded,
                name: 'LOW42 밸런스 국수면',
                detail: '담백하게 즐기는 한 끼',
                badge: 'NEW',
                onTap: () => _showPreparing(context),
              ),
              _ProductCard(
                icon: Icons.eco_rounded,
                name: 'LOW42 샐러드 키트',
                detail: '매장에서 만나는 신선함',
                badge: '매장 전용',
                onTap: () => _showPreparing(context),
              ),
              _ProductCard(
                icon: Icons.rice_bowl_rounded,
                name: 'LOW42 곤약 현미밥',
                detail: '든든한 식사 준비',
                badge: '출시 준비',
                onTap: () => _showPreparing(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: MembershipStore.instance,
            builder: (context, _) => AppCard(
              color: AppColors.surfaceWarm,
              onTap: onOpenProfile,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.lowSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_membership_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LOW42 멤버십',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '현재 ${MembershipStore.instance.stampProgress}/10 · 10회 방문 시 샐러드 무료',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '현재 쇼핑 화면은 제품 홍보용 시안이며 앱 내 결제 기능은 포함하지 않습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPreparing(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('상품 상세와 외부 쇼핑몰 연결을 준비하고 있습니다.')),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.icon,
    required this.name,
    required this.detail,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String detail;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 86,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lowSoft,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 39),
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
