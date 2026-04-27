// create_venue_screen.dart — 发布场馆
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/picked_location.dart';
import '../../models/profile.dart';
import '../../models/venue.dart';
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
  final String? editVenueId;
  const CreateVenueScreen({super.key, this.editVenueId});

  @override
  ConsumerState<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends ConsumerState<CreateVenueScreen> {
  final _name = TextEditingController();
  final _ownerName = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  final _price = TextEditingController(text: '0');
  final _fieldCount = TextEditingController(text: '1');
  PickedLocation? _location;
  String _venueType = 'private';
  String _sportType = 'football';
  String _fieldType = 'outdoor';
  String _startTime = '08:00';
  String _endTime = '22:00';
  bool _submitting = false;
  String? _coverUrl;
  bool _uploadingCover = false;
  final List<String> _photoUrls = [];
  final Set<int> _uploadingPhotoIndices = {};

  final List<String> _selectedFacilities = [];
  final _customFacility = TextEditingController();
  static const _presetFacilities = [
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

  bool get _isEditing => widget.editVenueId != null;

  @override
  void initState() {
    super.initState();
    if (widget.editVenueId != null) _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final venue = await ref.read(venuesRepoProvider).fetch(widget.editVenueId!);
      if (!mounted) return;
      setState(() {
        _name.text = venue.name;
        _desc.text = venue.description ?? '';
        _phone.text = venue.phone ?? '';
        _price.text = venue.pricePerHourYuan.toStringAsFixed(
          venue.pricePerHourCents % 100 == 0 ? 0 : 2,
        );
        _fieldCount.text = venue.fieldCount.toString();
        _ownerName.text = venue.ownerName ?? '';
        _venueType = venue.isPublic ? 'public' : 'private';
        _sportType = venue.sportType ?? 'football';
        _fieldType = switch (venue.fieldType) {
          VenueFieldType.indoor => 'indoor',
          VenueFieldType.semi => 'semi',
          VenueFieldType.outdoor => 'outdoor',
        };
        _coverUrl = venue.coverUrl;
        _photoUrls.addAll(venue.photos);
        _selectedFacilities.addAll(venue.facilities);
        _location = PickedLocation(
          name: venue.name,
          address: venue.address,
          lat: venue.lat,
          lng: venue.lng,
        );
        if (venue.openingHours != null && venue.openingHours!.contains('-')) {
          final parts = venue.openingHours!.split('-');
          _startTime = parts[0];
          _endTime = parts[1];
        }
      });
    } catch (e) {
      if (mounted) showToast(context, '加载场馆信息失败: $e', error: true);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _ownerName, _desc, _phone, _price, _fieldCount, _customFacility]) {
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

  Future<void> _addPhoto() async {
    if (_photoUrls.length >= 9) {
      showToast(context, '最多上传9张照片', error: true);
      return;
    }
    final uid = currentUserId;
    if (uid == null) return;
    final idx = _photoUrls.length;
    setState(() => _uploadingPhotoIndices.add(idx));
    try {
      final url = await StorageService().pickCropCompressAndUpload(
        bucket: 'venue-covers',
        pathPrefix: '$uid/photos',
        square: false,
      );
      if (url != null && mounted) {
        setState(() => _photoUrls.add(url));
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhotoIndices.remove(idx));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photoUrls.removeAt(index));
  }


  void _addCustomFacility() {
    final text = _customFacility.text.trim();
    if (text.isEmpty) return;
    if (_selectedFacilities.contains(text)) {
      _customFacility.clear();
      return;
    }
    setState(() {
      _selectedFacilities.add(text);
      _customFacility.clear();
    });
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
      final priceCents = ((double.tryParse(_price.text.trim()) ?? 0) * 100).round();
      final isPublic = _venueType == 'public';
      final payload = {
        'name': _name.text.trim(),
        'venue_type': _venueType,
        'owner_name': isPublic ? null : (_ownerName.text.trim().isNotEmpty ? _ownerName.text.trim() : null),
        'sport_type': _sportType,
        'description': _desc.text.trim().isNotEmpty ? _desc.text.trim() : null,
        'address': _location!.address,
        'lat': _location!.lat,
        'lng': _location!.lng,
        'phone': isPublic ? null : (_phone.text.trim().isNotEmpty ? _phone.text.trim() : null),
        'cover_url': _coverUrl,
        'photos': _photoUrls,
        'field_type': _fieldType,
        'field_count': int.tryParse(_fieldCount.text.trim()) ?? 1,
        'price_per_hour_cents': isPublic ? 0 : priceCents,
        'facilities': _selectedFacilities,
        'opening_hours': isPublic ? null : '$_startTime-$_endTime',
      };
      final repo = ref.read(venuesRepoProvider);
      if (_isEditing) {
        await repo.update(widget.editVenueId!, payload);
      } else {
        payload['owner_id'] = uid;
        payload['status'] = 'active';
        await repo.create(payload);
      }
      ref.invalidate(liveVenuesProvider);
      ref.invalidate(myVenuesProvider);
      if (_isEditing) ref.invalidate(venueDetailProvider(widget.editVenueId!));
      if (!mounted) return;
      showToast(context, _isEditing ? '场馆更新成功' : '场馆发布成功', success: true);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '${_isEditing ? '更新' : '发布'}失败: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delistVenue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.tokens;
        return AlertDialog(
          backgroundColor: t.elev2,
          title: Text('下架场馆', style: TextStyle(color: t.ink)),
          content: Text(
            '下架后场馆将不再显示在列表中，已有预约不受影响。确定要下架吗？',
            style: TextStyle(color: t.inkSub),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: t.inkSub)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('确定下架', style: TextStyle(color: t.danger)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(venuesRepoProvider).update(widget.editVenueId!, {'status': 'inactive'});
      ref.invalidate(liveVenuesProvider);
      ref.invalidate(myVenuesProvider);
      ref.invalidate(venueDetailProvider(widget.editVenueId!));
      if (!mounted) return;
      showToast(context, '场馆已下架', success: true);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '下架失败: $e', error: true);
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
            PageTitleBar(title: _isEditing ? '编辑场馆' : '发布场馆', onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  // Venue type
                  _SectionTitle('场馆类型'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final vt in [
                          ('public', '公共球场'),
                          ('private', '私人球场'),
                        ])
                          _ChoiceChip(
                            label: vt.$2,
                            selected: _venueType == vt.$1,
                            onTap: () => setState(() => _venueType = vt.$1),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cover photo
                  _CoverPicker(
                    url: _coverUrl,
                    uploading: _uploadingCover,
                    onTap: _pickCover,
                  ),

                  // Venue photos
                  _PhotoGrid(
                    urls: _photoUrls,
                    uploading: _uploadingPhotoIndices.isNotEmpty,
                    onAdd: _addPhoto,
                    onRemove: _removePhoto,
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

                  // Numeric fields (private only)
                  Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          label: '场地数量',
                          controller: _fieldCount,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      if (_venueType == 'private')
                        Expanded(
                          child: _TextField(
                            label: '每小时价格(元)',
                            controller: _price,
                            hint: '0 表示免费',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                    ],
                  ),
                  if (_venueType == 'private')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Label('营业时间'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final result = await showModalBottomSheet<(String, String)>(
                              context: context,
                              backgroundColor: t.elev1,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (_) => _OpeningHoursPickerSheet(
                                startTime: _startTime,
                                endTime: _endTime,
                              ),
                            );
                            if (result != null && mounted) {
                              setState(() {
                                _startTime = result.$1;
                                _endTime = result.$2;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: t.elev2,
                              border: Border.all(color: t.line),
                              borderRadius: BorderRadius.circular(t.r2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, size: 20, color: t.accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$_startTime — $_endTime',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: t.ink,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 20, color: t.inkMute),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_venueType == 'private') ...[
                    _OwnerNameField(
                      controller: _ownerName,
                      ref: ref,
                    ),
                    _TextField(
                      label: '联系电话',
                      controller: _phone,
                      hint: '方便用户联系您',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                  _TextField(
                    label: '场馆介绍',
                    controller: _desc,
                    maxLines: 3,
                  ),

                  // Facilities
                  _SectionTitle('配套设施'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _presetFacilities)
                          _ChoiceChip(
                            label: f,
                            selected: _selectedFacilities.contains(f),
                            onTap: () {
                              setState(() {
                                if (_selectedFacilities.contains(f)) {
                                  _selectedFacilities.remove(f);
                                } else {
                                  _selectedFacilities.add(f);
                                }
                              });
                            },
                          ),
                        for (final f in _selectedFacilities.where(
                          (f) => !_presetFacilities.contains(f),
                        ))
                          _ChoiceChip(
                            label: f,
                            selected: true,
                            onTap: () => setState(() => _selectedFacilities.remove(f)),
                            deletable: true,
                          ),
                      ],
                    ),
                  ),
                  // Custom facility input
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customFacility,
                            style: TextStyle(fontSize: 13, color: t.ink),
                            decoration: InputDecoration(
                              hintText: '添加自定义设施',
                              hintStyle: TextStyle(fontSize: 13, color: t.inkDim),
                              filled: true,
                              fillColor: t.elev2,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
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
                            onSubmitted: (_) => _addCustomFacility(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addCustomFacility,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(t.r2),
                            ),
                            child: Icon(Icons.add, size: 18, color: t.accentInk),
                          ),
                        ),
                      ],
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: _submitting
                        ? (_isEditing ? '保存中…' : '发布中…')
                        : (_isEditing ? '保存修改' : '发布场馆'),
                    variant: BtnVariant.primary,
                    size: BtnSize.lg,
                    full: true,
                    onPressed: _submitting ? null : _submit,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: '下架场馆',
                      variant: BtnVariant.ghost,
                      size: BtnSize.md,
                      full: true,
                      onPressed: _delistVenue,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningHoursPickerSheet extends StatefulWidget {
  final String startTime;
  final String endTime;
  const _OpeningHoursPickerSheet({
    required this.startTime,
    required this.endTime,
  });

  @override
  State<_OpeningHoursPickerSheet> createState() =>
      _OpeningHoursPickerSheetState();
}

class _OpeningHoursPickerSheetState extends State<_OpeningHoursPickerSheet> {
  static const _kItemExtent = 40.0;
  static const _kPickerHeight = 200.0;

  static final _timeSlots = [
    for (int h = 0; h < 24; h++) ...[
      '${h.toString().padLeft(2, '0')}:00',
      '${h.toString().padLeft(2, '0')}:30',
    ],
    '24:00',
  ];

  late int _startIndex;
  late int _endIndex;
  late final FixedExtentScrollController _startCtrl;
  late final FixedExtentScrollController _endCtrl;

  @override
  void initState() {
    super.initState();
    _startIndex = _timeSlots.indexOf(widget.startTime).clamp(0, _timeSlots.length - 1);
    _endIndex = _timeSlots.indexOf(widget.endTime).clamp(0, _timeSlots.length - 1);
    _startCtrl = FixedExtentScrollController(initialItem: _startIndex);
    _endCtrl = FixedExtentScrollController(initialItem: _endIndex);
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  bool get _isValid => _endIndex > _startIndex;

  String _durationLabel() {
    final totalMinutes = (_endIndex - _startIndex) * 30;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '共 $hours 小时';
    return '共 $hours 小时 $minutes 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.inkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header: cancel / title / confirm
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      '取消',
                      style: TextStyle(fontSize: 15, color: t.inkSub),
                    ),
                  ),
                  Text(
                    '营业时间',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  GestureDetector(
                    onTap: _isValid
                        ? () => Navigator.pop(
                              context,
                              (_timeSlots[_startIndex], _timeSlots[_endIndex]),
                            )
                        : null,
                    child: Text(
                      '确定',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _isValid ? t.accent : t.inkMute,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Live preview
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _timeSlots[_startIndex],
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _isValid ? t.accent : t.inkMute,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '—',
                          style: TextStyle(fontSize: 24, color: t.inkDim),
                        ),
                      ),
                      Text(
                        _timeSlots[_endIndex],
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _isValid ? t.accent : t.inkMute,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isValid ? _durationLabel() : '结束时间须晚于开始时间',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isValid ? t.inkSub : t.danger,
                    ),
                  ),
                ],
              ),
            ),
            // Dual pickers
            Row(
              children: [
                // Start time picker
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '开始时间',
                        style: TextStyle(fontSize: 12, color: t.inkDim),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: _kPickerHeight,
                        child: CupertinoPicker(
                          scrollController: _startCtrl,
                          itemExtent: _kItemExtent,
                          onSelectedItemChanged: (i) =>
                              setState(() => _startIndex = i),
                          selectionOverlay:
                              CupertinoPickerDefaultSelectionOverlay(
                            background: t.accent.withValues(alpha: 0.08),
                          ),
                          children: [
                            for (final slot in _timeSlots)
                              Center(
                                child: Text(
                                  slot,
                                  style: TextStyle(fontSize: 18, color: t.ink),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // End time picker
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '结束时间',
                        style: TextStyle(fontSize: 12, color: t.inkDim),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: _kPickerHeight,
                        child: CupertinoPicker(
                          scrollController: _endCtrl,
                          itemExtent: _kItemExtent,
                          onSelectedItemChanged: (i) =>
                              setState(() => _endIndex = i),
                          selectionOverlay:
                              CupertinoPickerDefaultSelectionOverlay(
                            background: t.accent.withValues(alpha: 0.08),
                          ),
                          children: [
                            for (final slot in _timeSlots)
                              Center(
                                child: Text(
                                  slot,
                                  style: TextStyle(fontSize: 18, color: t.ink),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
  final bool deletable;
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.deletable = false,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? t.accent : t.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (deletable) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: 14, color: t.accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<String> urls;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  const _PhotoGrid({
    required this.urls,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (urls.isEmpty && !uploading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: GestureDetector(
          onTap: onAdd,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: t.elev2,
              borderRadius: BorderRadius.circular(t.r2),
              border: Border.all(color: t.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 22, color: t.inkDim),
                const SizedBox(width: 8),
                Text(
                  '添加场馆照片（最多9张）',
                  style: TextStyle(fontSize: 13, color: t.inkDim),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final itemCount = urls.length + (urls.length < 9 ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (i == urls.length) {
              return GestureDetector(
                onTap: uploading ? null : onAdd,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: t.elev2,
                    borderRadius: BorderRadius.circular(t.r2),
                    border: Border.all(color: t.line),
                  ),
                  child: uploading
                      ? Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.accent,
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 24, color: t.inkDim),
                            Text(
                              '${urls.length}/9',
                              style: TextStyle(fontSize: 11, color: t.inkDim),
                            ),
                          ],
                        ),
                ),
              );
            }
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(t.r2),
                  child: Image.network(
                    urls[i],
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
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

class _OwnerNameField extends StatefulWidget {
  final TextEditingController controller;
  final WidgetRef ref;
  const _OwnerNameField({required this.controller, required this.ref});

  @override
  State<_OwnerNameField> createState() => _OwnerNameFieldState();
}

class _OwnerNameFieldState extends State<_OwnerNameField> {
  List<Profile> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;
  bool _ignoreNextChange = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    if (_ignoreNextChange) {
      _ignoreNextChange = false;
      return;
    }
    final q = widget.controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await widget.ref
            .read(profilesRepoProvider)
            .searchByName(q, limit: 5);
        if (mounted) {
          setState(() {
            _suggestions = results;
            _showSuggestions = results.isNotEmpty;
          });
        }
      } catch (_) {}
    });
  }

  void _selectProfile(Profile p) {
    _ignoreNextChange = true;
    widget.controller.text = p.name;
    widget.controller.selection = TextSelection.collapsed(
      offset: p.name.length,
    );
    setState(() => _showSuggestions = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label('负责人'),
          const SizedBox(height: 6),
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            style: TextStyle(fontSize: 14, color: t.ink),
            decoration: InputDecoration(
              hintText: '搜索用户或手动输入',
              hintStyle: TextStyle(fontSize: 14, color: t.inkDim),
              filled: true,
              fillColor: t.elev2,
              prefixIcon: Icon(Icons.person_outline, size: 20, color: t.inkDim),
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
          if (_showSuggestions)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: t.elev2,
                borderRadius: BorderRadius.circular(t.r2),
                border: Border.all(color: t.line),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: t.line),
                itemBuilder: (_, i) {
                  final p = _suggestions[i];
                  return GestureDetector(
                    onTap: () => _selectProfile(p),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: p.avatarUrl != null
                                ? NetworkImage(p.avatarUrl!)
                                : null,
                            backgroundColor: t.elev3,
                            child: p.avatarUrl == null
                                ? Icon(Icons.person, size: 16, color: t.inkDim)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: t.ink,
                                  ),
                                ),
                                if (p.handle != null)
                                  Text(
                                    '@${p.handle}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: t.inkSub,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
