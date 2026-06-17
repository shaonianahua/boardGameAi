import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../app/app_colors.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
              sliver: SliverToBoxAdapter(
                child: _Header(colorScheme: colorScheme, textTheme: textTheme),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
              sliver: SliverToBoxAdapter(
                child: _GameEntryCard(
                  onStart: () {
                    Get.snackbar(
                      '璀璨宝石',
                      '对局页将在下一步接入',
                      snackPosition: SnackPosition.BOTTOM,
                      margin: EdgeInsets.all(16.w),
                      borderRadius: 8,
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
              sliver: const SliverToBoxAdapter(child: _ProjectStagePanel()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colorScheme, required this.textTheme});

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.casino_outlined,
            color: colorScheme.onPrimary,
            size: 24.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI人玩桌游',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                '本地桌游模拟器',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.64),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameEntryCard extends StatelessWidget {
  const _GameEntryCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 116.w,
                  child: AspectRatio(
                    aspectRatio: 938 / 1200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'images/splendor/bg.webp',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '璀璨宝石',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '首个开发桌游',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.64),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: const [
                          _InfoChip(label: '2-4人'),
                          _InfoChip(label: '本地同屏'),
                          _InfoChip(label: 'V1'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始对局'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectStagePanel extends StatelessWidget {
  const _ProjectStagePanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前阶段',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12.h),
            _StageRow(
              icon: Icons.table_bar_outlined,
              color: colorScheme.primary,
              label: '璀璨宝石本地对局',
              value: '准备中',
            ),
            SizedBox(height: 10.h),
            _StageRow(
              icon: Icons.storage_outlined,
              color: colorScheme.secondary,
              label: '后端与存档边界',
              value: '已预留',
            ),
            SizedBox(height: 10.h),
            _StageRow(
              icon: Icons.psychology_alt_outlined,
              color: AppColors.splendorBlue,
              label: 'AI 策略模块',
              value: '后续',
            ),
          ],
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 19.sp),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
