import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/home/business_service.dart';

class AllCommentsPage extends StatefulWidget {
  const AllCommentsPage({super.key, required this.business, this.totalCount});

  final Business business;
  final int? totalCount;

  @override
  State<AllCommentsPage> createState() => _AllCommentsPageState();
}

class _AllCommentsPageState extends State<AllCommentsPage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);
  static const _pageSize = 20;

  final _service = BusinessService.instance;
  final _scroll = ScrollController();
  final _items = <StoreComment>[];
  final _ids = <String>{};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _moreError;
  int _req = 0; // mencegah respons lama menimpa hasil refresh

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _loadFirst({bool silent = false}) async {
    final req = ++_req;
    setState(() {
      _loadingMore = false;
      _moreError = null;
      if (!silent) {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await _service.fetchComments(
        widget.business.id,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted || req != _req) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page);
        _ids
          ..clear()
          ..addAll(page.map((c) => c.id));
        _hasMore = page.length == _pageSize;
        _loading = false;
        _error = null;
      });
    } on ServiceFailure catch (e) {
      if (!mounted || req != _req) return;
      if (silent) {
        _snack(e.message);
      } else {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _moreError != null) return;
    final req = _req;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.fetchComments(
        widget.business.id,
        limit: _pageSize,
        offset: _items.length,
      );
      if (!mounted || req != _req) return;
      setState(() {
        for (final c in page) {
          if (_ids.add(c.id)) _items.add(c);
        }
        _hasMore = page.length == _pageSize;
        _loadingMore = false;
      });
    } on ServiceFailure catch (e) {
      if (!mounted || req != _req) return;
      setState(() {
        _moreError = e.message;
        _loadingMore = false;
      });
    }
  }

  void _retryMore() {
    setState(() => _moreError = null);
    _loadMore();
  }

  // ---------- UI ----------

  Widget _header() {
    final total = widget.totalCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                'Customer Comments',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
              Positioned(
                top: -14,
                right: -22,
                child: Text(
                  '*',
                  style: GoogleFonts.poppins(
                    fontSize: 44,
                    fontWeight: FontWeight.w500,
                    color: _green,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Text(
                  '\u201C${widget.business.name}\u201D',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
              ),
              if (total != null) ...[
                const SizedBox(width: 8),
                Text(
                  '\u00B7 $total comment${total == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(fontSize: 13, color: _grey),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(StoreComment c) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!c.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 1),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                        child: Text(
                          c.authorMasked,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _label,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                timeAgo(c.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.body,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _label,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text, {VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: _grey),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Coba lagi',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _green),
          ),
        ),
      );
    }
    if (_moreError != null) return _message(_moreError!, onRetry: _retryMore);
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Semua komentar sudah ditampilkan.',
            style: GoogleFonts.poppins(fontSize: 12, color: _grey),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _green),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _message(_error!, onRetry: _loadFirst),
        ),
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: () => _loadFirst(silent: true),
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              children: [
                _message(
                  'Belum ada komentar yang dibaca.\nGeser komentar di dashboard ke kiri untuk memindahkannya ke sini.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 40),
              itemCount: _items.length + 1,
              itemBuilder: (_, i) =>
                  i < _items.length ? _card(_items[i]) : _footer(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),
                _header(),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
