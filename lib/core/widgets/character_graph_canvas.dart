import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'zm_widgets.dart';

class GraphNode {
  const GraphNode({
    required this.id,
    required this.name,
    this.camp,
    this.role,
    this.importance = 'normal',
    this.subtitle,
  });

  final String id;
  final String name;
  final String? camp;
  final String? role;
  final String importance; // 'major' | 'normal' | 'minor'
  final String? subtitle;
}

class GraphEdge {
  const GraphEdge({
    required this.id,
    required this.fromId,
    required this.toId,
    this.relationType = '未知',
    required this.label,
    this.description = '',
    this.strength = 3,
    this.line = '明线',
    this.firstChapter,
    this.lastChapter,
    this.evolution = const [],
  });

  final String id;
  final String fromId;
  final String toId;
  final String relationType;
  final String label;
  final String description;
  final int strength;
  final String line; // '明线' | '暗线'
  final int? firstChapter;
  final int? lastChapter;
  final List<({String chapterLabel, String state})> evolution;
}

Color relationTypeColor(String type) => switch (type) {
  '敌对' => const Color(0xFFE04F5F),
  '爱恋' => const Color(0xFFE95C9E),
  '亲友' => const Color(0xFF2FA88E),
  '盟友' => const Color(0xFF3E7BFA),
  '从属' => const Color(0xFFD98B2B),
  '竞争' => const Color(0xFF8B5CF6),
  _ => const Color(0xFF7A869A),
};

const List<Color> _campPalette = [
  Color(0xFF3E7BFA),
  Color(0xFF2FA88E),
  Color(0xFFE06D3E),
  Color(0xFF9353D3),
  Color(0xFFD98B2B),
  Color(0xFFE04F5F),
  Color(0xFF0EA5E9),
  Color(0xFF64748B),
];

Color campColorFor(String? camp, List<String> allCamps) {
  final c = (camp ?? '').trim();
  if (c.isEmpty || c == '独立') return const Color(0xFF4D5C91);
  final idx = allCamps.indexOf(c);
  if (idx < 0) return _campPalette[c.hashCode.abs() % _campPalette.length];
  return _campPalette[idx % _campPalette.length];
}

/// 纯 Dart 确定性力导向 + 阵营扇区初始化布局（零外部依赖，50 节点计算 <10ms）
abstract final class CharacterGraphLayout {
  static Map<String, Offset> compute(
    List<GraphNode> nodes,
    List<GraphEdge> edges, {
    Size canvasSize = const Size(1100, 760),
    int iterations = 80,
  }) {
    if (nodes.isEmpty) return const {};
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    if (nodes.length == 1) {
      return {nodes.first.id: Offset(cx, cy)};
    }

    final degree = <String, int>{for (final n in nodes) n.id: 0};
    for (final e in edges) {
      if (degree.containsKey(e.fromId) && degree.containsKey(e.toId)) {
        degree[e.fromId] = degree[e.fromId]! + 1;
        degree[e.toId] = degree[e.toId]! + 1;
      }
    }

    // 按阵营划分扇区，核心角色居中、其余按阵营扇区分布
    final camps = <String>[];
    for (final n in nodes) {
      final c = (n.camp ?? '独立').trim().isEmpty ? '独立' : n.camp!.trim();
      if (!camps.contains(c)) camps.add(c);
    }
    final byCamp = <String, List<GraphNode>>{};
    for (final n in nodes) {
      final c = (n.camp ?? '独立').trim().isEmpty ? '独立' : n.camp!.trim();
      byCamp.putIfAbsent(c, () => []).add(n);
    }

    final pos = <String, Offset>{};
    final baseRadius = math.min(canvasSize.width, canvasSize.height) * 0.34;
    for (var ci = 0; ci < camps.length; ci++) {
      final list = byCamp[camps[ci]]!;
      final sectorAngle = (2 * math.pi * ci) / math.max(1, camps.length);
      final sectorSpan = (2 * math.pi) / math.max(1, camps.length) * 0.72;
      for (var i = 0; i < list.length; i++) {
        final node = list[i];
        final isHub =
            node.importance == 'major' && (degree[node.id] ?? 0) >= 2;
        final frac = list.length == 1 ? 0.0 : (i / (list.length - 1)) - 0.5;
        final angle = sectorAngle + frac * sectorSpan;
        final r = isHub
            ? baseRadius * (0.28 + (i % 3) * 0.14)
            : baseRadius * (0.68 + ((i % 3) * 0.15));
        pos[node.id] = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
      }
    }

    // Fruchterman-Reingold 确定性迭代
    final area = canvasSize.width * canvasSize.height;
    final k = math.sqrt(area / nodes.length) * 0.72;
    const padX = 72.0;
    const padY = 58.0;
    var temp = math.min(canvasSize.width, canvasSize.height) * 0.12;
    final ids = nodes.map((n) => n.id).toList();

    for (var iter = 0; iter < iterations; iter++) {
      final disp = <String, Offset>{for (final id in ids) id: Offset.zero};

      // 节点间斥力
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final a = ids[i];
          final b = ids[j];
          var delta = pos[a]! - pos[b]!;
          var dist = delta.distance;
          if (dist < 0.01) {
            delta = Offset((i - j).toDouble(), 1.0);
            dist = delta.distance;
          }
          final repulse = (k * k) / dist;
          final f = (delta / dist) * repulse;
          disp[a] = disp[a]! + f;
          disp[b] = disp[b]! - f;
        }
      }

      // 边引力
      for (final e in edges) {
        final pa = pos[e.fromId];
        final pb = pos[e.toId];
        if (pa == null || pb == null) continue;
        final delta = pa - pb;
        final dist = math.max(1.0, delta.distance);
        final weight = 0.75 + e.strength * 0.12;
        final attract = ((dist * dist) / k) * weight;
        final f = (delta / dist) * attract;
        disp[e.fromId] = disp[e.fromId]! - f;
        disp[e.toId] = disp[e.toId]! + f;
      }

      // 轻度向心引力防止离散孤岛飘出边界
      for (final id in ids) {
        final toCenter = Offset(cx, cy) - pos[id]!;
        disp[id] = disp[id]! + toCenter * 0.04;
      }

      for (final id in ids) {
        final d = disp[id]!;
        final len = d.distance;
        if (len > 0.001) {
          final step = (d / len) * math.min(len, temp);
          final next = pos[id]! + step;
          pos[id] = Offset(
            next.dx.clamp(padX, canvasSize.width - padX),
            next.dy.clamp(padY, canvasSize.height - padY),
          );
        }
      }
      temp *= 0.94;
    }

    return pos;
  }
}

/// 纯 Flutter 原生交互式人物关系图谱组件（星图画布 / 关系列表双视图）
class CharacterGraphCanvas extends StatefulWidget {
  const CharacterGraphCanvas({
    super.key,
    required this.nodes,
    required this.edges,
    this.onAddRelation,
    this.onEditRelation,
    this.onDeleteRelation,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final VoidCallback? onAddRelation;
  final ValueChanged<GraphEdge>? onEditRelation;
  final ValueChanged<GraphEdge>? onDeleteRelation;

  @override
  State<CharacterGraphCanvas> createState() => _CharacterGraphCanvasState();
}

class _CharacterGraphCanvasState extends State<CharacterGraphCanvas> {
  static const Size _boardSize = Size(1200, 820);

  bool _listMode = false;
  String? _selectedCamp;
  String? _selectedType;
  bool _onlyDarkLine = false;
  String _search = '';
  String? _selectedNodeId;
  Map<String, Offset> _positions = const {};
  String _layoutSignature = '';

  @override
  void initState() {
    super.initState();
    _ensureLayout();
  }

  @override
  void didUpdateWidget(covariant CharacterGraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureLayout();
  }

  void _ensureLayout() {
    final sig =
        '${widget.nodes.map((n) => n.id).join(",")}|${widget.edges.map((e) => e.id).join(",")}';
    if (sig == _layoutSignature) return;
    _layoutSignature = sig;
    _positions = CharacterGraphLayout.compute(
      widget.nodes,
      widget.edges,
      canvasSize: _boardSize,
    );
    if (_selectedNodeId != null &&
        !widget.nodes.any((n) => n.id == _selectedNodeId)) {
      _selectedNodeId = null;
    }
  }

  List<String> get _allCamps {
    final set = <String>{};
    for (final n in widget.nodes) {
      final c = (n.camp ?? '').trim();
      if (c.isNotEmpty) set.add(c);
    }
    return set.toList()..sort();
  }

  List<GraphEdge> get _filteredEdges {
    final q = _search.trim().toLowerCase();
    final nodeMap = {for (final n in widget.nodes) n.id: n};
    return widget.edges.where((e) {
      if (_onlyDarkLine && e.line != '暗线') return false;
      if (_selectedType != null && e.relationType != _selectedType) return false;
      final a = nodeMap[e.fromId];
      final b = nodeMap[e.toId];
      if (a == null || b == null) return false;
      if (_selectedCamp != null &&
          (a.camp ?? '') != _selectedCamp &&
          (b.camp ?? '') != _selectedCamp) {
        return false;
      }
      if (q.isNotEmpty) {
        final match =
            a.name.toLowerCase().contains(q) ||
            b.name.toLowerCase().contains(q) ||
            e.label.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  List<GraphNode> get _filteredNodes {
    final q = _search.trim().toLowerCase();
    return widget.nodes.where((n) {
      if (_selectedCamp != null && (n.camp ?? '') != _selectedCamp) {
        return false;
      }
      if (q.isNotEmpty && !n.name.toLowerCase().contains(q)) {
        return _filteredEdges.any(
          (e) => e.fromId == n.id || e.toId == n.id,
        );
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final camps = _allCamps;
    final visibleNodes = _filteredNodes;
    final visibleEdges = _filteredEdges;
    final nodeMap = {for (final n in widget.nodes) n.id: n};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('星图'),
                    icon: Icon(Icons.hub_outlined, size: 15),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('列表'),
                    icon: Icon(Icons.view_list_outlined, size: 15),
                  ),
                ],
                selected: {_listMode},
                onSelectionChanged: (s) => setState(() => _listMode = s.first),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '搜索角色/关系…',
                    prefixIcon: Icon(Icons.search, size: 16),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              if (camps.isNotEmpty)
                DropdownButton<String?>(
                  value: _selectedCamp,
                  hint: const Text('全部阵营', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('全部阵营', style: TextStyle(fontSize: 12)),
                    ),
                    for (final c in camps)
                      DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selectedCamp = v),
                ),
              DropdownButton<String?>(
                value: _selectedType,
                hint: const Text('全部类型', style: TextStyle(fontSize: 12)),
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('全部类型', style: TextStyle(fontSize: 12)),
                  ),
                  for (final t in ['亲友', '盟友', '爱恋', '敌对', '从属', '竞争', '未知'])
                    DropdownMenuItem(
                      value: t,
                      child: Text(t, style: const TextStyle(fontSize: 12)),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedType = v),
              ),
              FilterChip(
                label: const Text('仅暗线', style: TextStyle(fontSize: 12)),
                selected: _onlyDarkLine,
                onSelected: (v) => setState(() => _onlyDarkLine = v),
                visualDensity: VisualDensity.compact,
              ),
              if (widget.onAddRelation != null)
                FilledButton.tonalIcon(
                  onPressed: widget.onAddRelation,
                  icon: const Icon(Icons.add_link, size: 16),
                  label: const Text('新增关系'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: widget.nodes.isEmpty
              ? const ZmEmptyState(
                  icon: Icons.hub_outlined,
                  title: '暂无角色与关系数据',
                  description: '请先添加角色，或通过续写精扫/章节摘要活账本自动生成人物关系图谱。',
                )
              : _listMode
              ? _buildListView(visibleEdges, nodeMap, cs)
              : _buildGraphView(visibleNodes, visibleEdges, camps, nodeMap, cs),
        ),
      ],
    );
  }

  Widget _buildGraphView(
    List<GraphNode> visibleNodes,
    List<GraphEdge> visibleEdges,
    List<String> camps,
    Map<String, GraphNode> nodeMap,
    ColorScheme cs,
  ) {
    final visibleNodeIds = visibleNodes.map((n) => n.id).toSet();
    final drawableEdges = visibleEdges
        .where(
          (e) =>
              visibleNodeIds.contains(e.fromId) &&
              visibleNodeIds.contains(e.toId),
        )
        .toList();

    final highlightedNodes = <String>{};
    if (_selectedNodeId != null) {
      highlightedNodes.add(_selectedNodeId!);
      for (final e in drawableEdges) {
        if (e.fromId == _selectedNodeId) highlightedNodes.add(e.toId);
        if (e.toId == _selectedNodeId) highlightedNodes.add(e.fromId);
      }
    }

    final degree = <String, int>{for (final n in visibleNodes) n.id: 0};
    for (final e in drawableEdges) {
      degree[e.fromId] = (degree[e.fromId] ?? 0) + 1;
      degree[e.toId] = (degree[e.toId] ?? 0) + 1;
    }

    final graphArea = GestureDetector(
      onTap: () => setState(() => _selectedNodeId = null),
      child: Container(
        color: cs.surfaceContainerLowest,
        child: InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(240),
          minScale: 0.35,
          maxScale: 2.8,
          child: SizedBox(
            width: _boardSize.width,
            height: _boardSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GraphEdgePainter(
                      edges: drawableEdges,
                      positions: _positions,
                      selectedNodeId: _selectedNodeId,
                      textColor: cs.onSurfaceVariant,
                      surfaceColor: cs.surface,
                    ),
                  ),
                ),
                for (final node in visibleNodes)
                  _buildPositionedNode(
                    node: node,
                    pos: _positions[node.id] ??
                        Offset(_boardSize.width / 2, _boardSize.height / 2),
                    deg: degree[node.id] ?? 0,
                    campColor: campColorFor(node.camp, camps),
                    dimmed:
                        _selectedNodeId != null &&
                        !highlightedNodes.contains(node.id),
                    selected: _selectedNodeId == node.id,
                    cs: cs,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final selectedNode =
        _selectedNodeId != null ? nodeMap[_selectedNodeId!] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        if (selectedNode == null) return graphArea;
        final inspector = _buildNodeInspector(
          selectedNode,
          drawableEdges
              .where(
                (e) =>
                    e.fromId == selectedNode.id || e.toId == selectedNode.id,
              )
              .toList(),
          nodeMap,
          cs,
        );
        if (wide) {
          return Row(
            children: [
              Expanded(child: graphArea),
              const VerticalDivider(width: 1),
              SizedBox(width: 300, child: inspector),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: graphArea),
            const Divider(height: 1),
            SizedBox(height: 220, child: inspector),
          ],
        );
      },
    );
  }

  Widget _buildPositionedNode({
    required GraphNode node,
    required Offset pos,
    required int deg,
    required Color campColor,
    required bool dimmed,
    required bool selected,
    required ColorScheme cs,
  }) {
    final radius = (node.importance == 'major' ? 28.0 : 21.0) +
        math.min(deg * 1.4, 8.0);
    return Positioned(
      left: pos.dx - radius - 26,
      top: pos.dy - radius,
      width: (radius + 26) * 2,
      child: Opacity(
        opacity: dimmed ? 0.22 : 1.0,
        child: GestureDetector(
          onTap: () => setState(() {
            _selectedNodeId = _selectedNodeId == node.id ? null : node.id;
          }),
          onPanUpdate: (d) {
            setState(() {
              final cur = _positions[node.id] ?? pos;
              _positions = {
                ..._positions,
                node.id: Offset(
                  (cur.dx + d.delta.dx).clamp(40, _boardSize.width - 40),
                  (cur.dy + d.delta.dy).clamp(40, _boardSize.height - 40),
                ),
              };
            });
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? campColor
                      : campColor.withValues(alpha: 0.16),
                  border: Border.all(
                    color: campColor,
                    width: selected ? 3 : 2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: campColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  node.name.isNotEmpty ? node.name.substring(0, 1) : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: node.importance == 'major' ? 16 : 13,
                    color: selected ? Colors.white : campColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeInspector(
    GraphNode node,
    List<GraphEdge> connected,
    Map<String, GraphNode> nodeMap,
    ColorScheme cs,
  ) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                node.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _selectedNodeId = null),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if ((node.role ?? '').isNotEmpty)
              Chip(
                label: Text(node.role!, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            if ((node.camp ?? '').isNotEmpty)
              Chip(
                label: Text(
                  '阵营：${node.camp}',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if ((node.subtitle ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            node.subtitle!,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          '关联关系（${connected.length}）',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (connected.isEmpty)
          Text(
            '当前筛选条件下暂无关联边',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          )
        else
          for (final e in connected)
            _buildRelationCard(e, nodeMap, cs, compact: true),
      ],
    );
  }

  Widget _buildListView(
    List<GraphEdge> edges,
    Map<String, GraphNode> nodeMap,
    ColorScheme cs,
  ) {
    if (edges.isEmpty) {
      return ZmEmptyState(
        icon: Icons.link_off,
        title: '暂无符合条件的关系记录',
        description: '可调整上方筛选条件，或点击「新增关系」手动维护人物关系。',
        action: widget.onAddRelation != null
            ? FilledButton.tonalIcon(
                onPressed: widget.onAddRelation,
                icon: const Icon(Icons.add_link),
                label: const Text('新增关系'),
              )
            : null,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTokens.s3),
      itemCount: edges.length,
      itemBuilder: (_, i) => _buildRelationCard(edges[i], nodeMap, cs),
    );
  }

  Widget _buildRelationCard(
    GraphEdge e,
    Map<String, GraphNode> nodeMap,
    ColorScheme cs, {
    bool compact = false,
  }) {
    final fromName = nodeMap[e.fromId]?.name ?? e.fromId;
    final toName = nodeMap[e.toId]?.name ?? e.toId;
    final tint = relationTypeColor(e.relationType);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$fromName ↔ $toName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${e.relationType}·${e.line}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  ),
                ),
                if (widget.onEditRelation != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onEditRelation!(e),
                  ),
                if (widget.onDeleteRelation != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onDeleteRelation!(e),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${e.label}  ·  强度 ${'★' * e.strength}${'☆' * (5 - e.strength)}'
              '${e.firstChapter != null ? '  ·  第${e.firstChapter}${e.lastChapter != null && e.lastChapter != e.firstChapter ? '-${e.lastChapter}' : ''}章' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            if (e.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                e.description,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
            if (e.evolution.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final pt in e.evolution)
                Text(
                  '• ${pt.chapterLabel.isEmpty ? '节点' : pt.chapterLabel}：${pt.state}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GraphEdgePainter extends CustomPainter {
  const _GraphEdgePainter({
    required this.edges,
    required this.positions,
    required this.selectedNodeId,
    required this.textColor,
    required this.surfaceColor,
  });

  final List<GraphEdge> edges;
  final Map<String, Offset> positions;
  final String? selectedNodeId;
  final Color textColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final a = positions[e.fromId];
      final b = positions[e.toId];
      if (a == null || b == null) continue;
      final isHighlighted =
          selectedNodeId == null ||
          e.fromId == selectedNodeId ||
          e.toId == selectedNodeId;
      final color = relationTypeColor(
        e.relationType,
      ).withValues(alpha: isHighlighted ? 0.78 : 0.14);
      final paint = Paint()
        ..color = color
        ..strokeWidth = (1.0 + e.strength * 0.65)
        ..style = PaintingStyle.stroke;

      if (e.line == '暗线') {
        _drawDashedLine(canvas, a, b, paint);
      } else {
        canvas.drawLine(a, b, paint);
      }

      if (isHighlighted && e.label.isNotEmpty) {
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: e.label.length > 8 ? '${e.label.substring(0, 7)}…' : e.label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              backgroundColor: surfaceColor.withValues(alpha: 0.84),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 7.0;
    const gapLen = 5.0;
    final diff = b - a;
    final dist = diff.distance;
    if (dist < 1) return;
    final dir = diff / dist;
    var cur = 0.0;
    while (cur < dist) {
      final next = math.min(cur + dashLen, dist);
      canvas.drawLine(a + dir * cur, a + dir * next, paint);
      cur += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) =>
      oldDelegate.edges != edges ||
      oldDelegate.positions != positions ||
      oldDelegate.selectedNodeId != selectedNodeId;
}
