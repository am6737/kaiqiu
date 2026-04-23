// create_venue_screen.dart — 发布场馆
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/picked_location.dart';
import '../../providers.dart';
import '../../services/storage.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import '../pickup/location_picker.dart';

class CreateVenueScreen extends ConsumerStatefulWidget {
  const CreateVenueScreen({super.key});

  @override
  ConsumerState<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends ConsumerState<CreateVenueScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  final _price = TextEditingController(text: '0');
  final _fieldCount = TextEditingController(text: '1');
  final _openingHours = TextEditingController(text: '08:00-22:00');
  PickedLocation? _location;
  String _sportType = 'football';
  String _fieldType = 'outdoor';
  bool _submitting = false;
  String? _coverUrl;
  bool _uploadingCover = false;

  final List<String> _selectedFacilities = [];
  static const _allFacilities = [
    '更衣室',
    '停车场',
    '灯光',
    '淋浴',
    '饮水',
    '洗手间',
    'WiFi',
    '储物柜',
    '观众席',
  ];

  @override
  void dispose() {
    for (final c in [_name, _desc, _phone, _price, _fieldCount, _openingHours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    final uid = currentUserId;
    if (uid == null) return;
    setState(() => _uploadingCover = true);
    try {
      final url = await StorageService().pickCropCompressAndUpload(
        bucket: 'venue-covers',
        pathPrefix: uid,
        square: false,
      );
      if (url != null && mounted) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() => _location = result);
    }
  }

  Future<void> _submit() async {
    final uid = currentUserId;
    if (uid == null) {
      showToast(context, '请先登录', error: true);
      return;
    }
    if (_name.text.trim().isEmpty) {
      showToast(context, '请填写场馆名称', error: true);
      return;
    }
    if (_location == null) {
      showToast(context, '请选择场馆位置', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final priceCents = (int.tryParse(_price.text.trim()) ?? 0) * 100;
      await ref.read(venuesRepoProvider).create({
        'owner_id': uid,
        'name': _name.text.trim(),
        'sport_type': _sportType,
        'description': _desc.text.trim().isNotEmpty ? _desc.text.trim() : null,
        'address': _location!.address,
        'lat': _location!.lat,
        'lng': _location!.lng,
        'phone': _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
        'cover_url': _coverUrl,
        'field_type': _fieldType,
        'field_count': int.tryParse(_fieldCount.text.trim()) ?? 1,
        'price_per_hour_cents': priceCents,
        'facilities': _selectedFacilities,
        'opening_hours': _openingHours.text.trim().isNotEmpty
            ? _openingHours.text.trim()
            : null,
        'status': 'active',
      });
      ref.invalidate(liveVenuesProvider);
      ref.invalidate(myVenuesProvider);
      if (!mounted) return;
      showToast(context, '场馆发布成功', success: true);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '发布失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(title: '发布场馆', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  // Cover photo
                  _CoverPicker(
                    url: _coverUrl,
                    uploading: _uploadingCover,
                    onTap: _pickCover,
                  ),

                  _TextField(label: '场馆名称', controller: _name, hint: '如：阳光足球公园'),
                  const SizedBox(height: 4),

                  // Sport type
                  _SectionTitle('运动类型'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in [
                          ('football', '足球'),
                          ('basketball', '篮球'),
                          ('badminton', '羽毛球'),
                          ('tennis', '网球'),
                          ('volleyball', '排球'),
                          ('tabletennis', '乒乓球'),
                        ])
                          _ChoiceChip(
                            label: s.$2,
                            selected: _sportType == s.$1,
                            onTap: () => setState(() => _sportType = s.$1),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field type
                  _SectionTitle('场地类型'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final f in [
                          ('outdoor', '室外'),
                          ('indoor', '室内'),
                          ('semi', '半室内'),
                        ])
                          _ChoiceChip(
                            label: f.$2,
                            selected: _fieldType == f.$1,
                            onTap: () => setState(() => _fieldType = f.$1),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Label('场馆位置'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: t.elev2,
                              border: Border.all(color: t.line),
                              borderRadius: BorderRadius.circular(t.r2),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                  color: _location != null
                                      ? t.accent
                                      : t.inkDim,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _location != null
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _location!.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: t.ink,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              _location!.address,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: t.inkSub,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          '选择场馆位置',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: t.inkDim,
                                          ),
                                        ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: t.inkMute,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Numeric fields
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          label: '场地数量',
                          controller: _fieldCount,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      Expanded(
                        child: _TextField(
                          label: '每小时价格(元)',
                          controller: _price,
                          hint: '0 表示免费',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  _TextField(
                    label: '营业时间',
                    controller: _openingHours,
                    hint: '如 08:00-22:00',
                  ),
                  _TextField(
                    label: '联系电话',
                    controller: _phone,
                    hint: '方便用户联系您',
                    keyboardType: TextInputType.phone,
                  ),
                  _TextField(
                    label: '场馆介绍',
                    controller: _desc,
                    hint: '介绍一下您的场馆',
                    maxLines: 3,
                  ),

                  // Facilities
                  _SectionTitle('配套设施'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allFacilities.map((f) {
                        final selected = _selectedFacilities.contains(f);
                        return _ChoiceChip(
                          label: f,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedFacilities.remove(f);
                              } else {
                                _selectedFacilities.add(f);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Submit button
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: t.elev1,
                border: Border(top: BorderSide(color: t.line)),
              ),
              child: PrimaryButton(
                label: _submitting ? '发布中…' : '发布场馆',
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  final String? url;
  final bool uploading;
  final VoidCallback onTap;
  const _CoverPicker({this.url, required this.uploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        height: 160,
        decoration: BoxDecoration(
          color: t.elev2,
          borderRadius: BorderRadius.circular(t.r3),
          border: Border.all(color: t.line),
          image: url != null
              ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
              : null,
        ),
        child: url == null
            ? Center(
                child: uploading
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.accent,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo, size: 32, color: t.inkDim),
                          const SizedBox(height: 6),
                          Text(
                            '添加场馆封面',
                            style: TextStyle(fontSize: 13, color: t.inkDim),
                          ),
                        ],
                      ),
              )
            : null,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.tokens.inkSub,
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? t.accentSubtle : t.elev2,
          border: Border.all(color: selected ? t.accent : t.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? t.accent : t.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  const _TextField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(fontSize: 14, color: t.ink),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 14, color: t.inkDim),
              filled: true,
              fillColor: t.elev2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.r2),
                borderSide: BorderSide(color: t.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.r2),
                borderSide: BorderSide(color: t.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.r2),
                borderSide: BorderSide(color: t.accent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
