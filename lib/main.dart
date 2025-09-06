import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GraphViewPage(),
    );
  }
}

class TreeNode {
  String id;
  String label;
  List<TreeNode> children;

  TreeNode({required this.id, required this.label, List<TreeNode>? children})
    : children = children ?? [];
}

class GraphViewPage extends StatefulWidget {
  const GraphViewPage({super.key});

  @override
  State<GraphViewPage> createState() => _GraphViewPageState();
}

class _GraphViewPageState extends State<GraphViewPage> {
  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  late TreeNode root;
  int _idCounter = 1;

  static const double nodeW = 100;
  static const double nodeH = 100;
  static const double horizontalGapBetweenChildren = 20;
  static const double verticalGapBetweenLevels = 120;
  static const double canvasMargin = 100;
  static const int maxDepth = 10;

  @override
  void initState() {
    super.initState();
    root = TreeNode(id: 'n0', label: 'Root');
  }

  void addChild(String parentId) {
    final parent = _findNodeById(root, parentId);
    if (parent == null) return;

    final depthOfParent = _computeNodeDepth(root, parentId);
    if (depthOfParent + 1 > maxDepth) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ Max depth 100 reached!")));
      return;
    }

    setState(() {
      parent.children.add(
        TreeNode(id: 'n${++_idCounter}', label: 'Node $_idCounter'),
      );
    });
  }

  void removeNode(String nodeId) {
    if (nodeId == root.id) return;
    final parent = _findParent(root, nodeId);
    if (parent == null) return;
    setState(() {
      parent.children.removeWhere((c) => c.id == nodeId);
    });
  }

  TreeNode? _findNodeById(TreeNode node, String id) {
    if (node.id == id) return node;
    for (final c in node.children) {
      final found = _findNodeById(c, id);
      if (found != null) return found;
    }
    return null;
  }

  TreeNode? _findParent(TreeNode node, String childId) {
    for (final c in node.children) {
      if (c.id == childId) return node;
      final deeper = _findParent(c, childId);
      if (deeper != null) return deeper;
    }
    return null;
  }

  Map<String, double> _computeSubtreeWidths(TreeNode node) {
    final Map<String, double> widths = {};
    double helper(TreeNode n) {
      if (n.children.isEmpty) {
        widths[n.id] = nodeW;
        return nodeW;
      }
      double total = 0;
      for (int i = 0; i < n.children.length; i++) {
        final cw = helper(n.children[i]);
        total += cw;
        if (i < n.children.length - 1) total += horizontalGapBetweenChildren;
      }
      widths[n.id] = total;
      return total;
    }

    helper(node);
    return widths;
  }

  int _computeDepth(TreeNode node) {
    if (node.children.isEmpty) return 1;
    int maxChild = 0;
    for (final c in node.children) {
      maxChild = maxChild > _computeDepth(c) ? maxChild : _computeDepth(c);
    }
    return 1 + maxChild;
  }

  // Depth of specific node in tree
  int _computeNodeDepth(TreeNode node, String id, [int depth = 1]) {
    if (node.id == id) return depth;
    for (final c in node.children) {
      final d = _computeNodeDepth(c, id, depth + 1);
      if (d != -1) return d;
    }
    return -1;
  }

  Map<String, Offset> _computePositions(
    TreeNode node,
    Map<String, double> widths,
    double startX,
    double y,
  ) {
    final Map<String, Offset> positions = {};

    void helper(TreeNode n, double sx, double sy) {
      final subtreeW = widths[n.id]!;
      if (n.children.isEmpty) {
        positions[n.id] = Offset(sx, sy);
      } else {
        double cx = sx;
        for (final child in n.children) {
          final childW = widths[child.id]!;
          helper(child, cx, sy + verticalGapBetweenLevels);
          cx += childW + horizontalGapBetweenChildren;
        }
        final parentX = sx + (subtreeW - nodeW) / 2;
        positions[n.id] = Offset(parentX, sy);
      }
    }

    helper(node, startX, y);
    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final widths = _computeSubtreeWidths(root);
    final rootWidth = widths[root.id] ?? nodeW;
    final canvasWidth = (rootWidth + canvasMargin * 2).clamp(
      screenSize.width,
      double.infinity,
    );
    final depth = _computeDepth(root);
    final canvasHeight =
        (depth * verticalGapBetweenLevels) + nodeH + canvasMargin * 2;

    final startX = (canvasWidth - rootWidth) / 2;
    final positions = _computePositions(root, widths, startX, canvasMargin);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey,
        title: Center(
          child: const Text(
            'Graph Builder',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Stack(
        children: [
          Scrollbar(
            controller: _vController,
            thumbVisibility: true,
            child: Scrollbar(
              controller: _hController,
              thumbVisibility: true,
              notificationPredicate: (notif) =>
                  notif.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _vController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  controller: _hController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: canvasWidth,
                      minHeight: canvasHeight,
                    ),
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(canvasWidth, canvasHeight),
                            painter: ConnectorPainter(
                              root: root,
                              positions: positions,
                            ),
                          ),
                          ..._buildNodeWidgets(root, positions),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Depth: $depth / $maxDepth",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNodeWidgets(TreeNode node, Map<String, Offset> positions) {
    final list = <Widget>[];

    void helper(TreeNode n) {
      final pos = positions[n.id] ?? Offset.zero;
      final childCount = n.children.length;

      list.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => addChild(n.id),
                  child: _NodeWidget(
                    label: "${n.label}\n($childCount children)",
                    width: nodeW,
                    height: nodeH,
                  ),
                ),
              ),
              if (n.id != root.id)
                Positioned(
                  right: -5,
                  top: -5,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => removeNode(n.id),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

      for (final c in n.children) helper(c);
    }

    helper(node);
    return list;
  }

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }
}

class _NodeWidget extends StatefulWidget {
  final String label;
  final double width;
  final double height;

  const _NodeWidget({
    required this.label,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  State<_NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<_NodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    // Start animation when widget is inserted
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D9CDB), Color(0xFF2F80ED)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectorPainter extends CustomPainter {
  final TreeNode root;
  final Map<String, Offset> positions;
  static const double nodeW = 100;
  static const double nodeH = 100;

  ConnectorPainter({required this.root, required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    void drawFor(TreeNode node) {
      final parentPos = positions[node.id];
      if (parentPos == null) return;
      final parentCenter = parentPos + const Offset(nodeW / 2, nodeH / 2);

      if (node.children.isEmpty) return;

      final childCenters = <Offset>[];
      for (final c in node.children) {
        final cp = positions[c.id];
        if (cp != null)
          childCenters.add(cp + const Offset(nodeW / 2, nodeH / 2));
      }
      if (childCenters.isEmpty) return;

      if (childCenters.length == 1) {
        canvas.drawLine(parentCenter, childCenters.first, paint);
      } else {
        final childY = childCenters.first.dy;
        final midY = (parentCenter.dy + childY) / 2;

        canvas.drawLine(parentCenter, Offset(parentCenter.dx, midY), paint);

        final leftX = childCenters
            .map((c) => c.dx)
            .reduce((a, b) => a < b ? a : b);
        final rightX = childCenters
            .map((c) => c.dx)
            .reduce((a, b) => a > b ? a : b);
        canvas.drawLine(Offset(leftX, midY), Offset(rightX, midY), paint);

        for (final cc in childCenters) {
          canvas.drawLine(Offset(cc.dx, midY), cc, paint);
        }
      }

      for (final c in node.children) {
        drawFor(c);
      }
    }

    drawFor(root);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
