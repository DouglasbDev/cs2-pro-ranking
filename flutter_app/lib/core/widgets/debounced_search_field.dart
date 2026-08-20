import 'package:flutter/material.dart';

import '../mixins/debounce_mixin.dart';
import '../theme/app_colors.dart';

const double _fieldCornerRadius = 12.0;
const double _hintFontSize = 14.0;
const double _iconSize = 20.0;
const double _clearIconSize = 18.0;
const double _verticalContentPadding = 14.0;

/// A search box that only calls [onChanged] after the user stops typing
/// for [debounce] — each keystroke resets the timer via [DebounceMixin], so
/// a fast typist never triggers a filter pass per character, only once
/// they pause.
class DebouncedSearchField extends StatefulWidget {
  const DebouncedSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final Duration debounce;

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField>
    with DebounceMixin<DebouncedSearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    setDebounceDuration(widget.debounce);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    cancelDebounce();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(_fieldCornerRadius),
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          onDebounce(() => widget.onChanged(value));
          setState(() {}); // only to toggle the clear button's visibility
        },
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: _hintFontSize),
        cursorColor: AppColors.gold,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
              color: AppColors.textSecondary, fontSize: _hintFontSize),
          prefixIcon: const Icon(Icons.search,
              color: AppColors.textSecondary, size: _iconSize),
          suffixIcon: switch (_controller.text) {
            '' => null,
            _ => IconButton(
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textSecondary,
                  size: _clearIconSize,
                ),
                onPressed: _clear,
              ),
          },
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: _verticalContentPadding),
        ),
      ),
    );
  }
}
