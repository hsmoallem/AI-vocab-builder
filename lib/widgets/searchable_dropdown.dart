import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String labelText;
  final String searchHint;
  final String Function(T) itemAsString;
  final bool hideUnderline;

  const SearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelText,
    this.searchHint = 'Search...',
    required this.itemAsString,
    this.hideUnderline = false,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dropdown = DropdownButtonFormField2<T>(
      value: widget.value,
      decoration: InputDecoration(
        labelText: widget.labelText.isEmpty ? null : widget.labelText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: widget.hideUnderline 
            ? InputBorder.none 
            : OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      isExpanded: true,
      items: widget.items,
      onChanged: widget.onChanged,
      dropdownStyleData: DropdownStyleData(
        maxHeight: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dropdownSearchData: DropdownSearchData(
        searchController: _searchController,
        searchInnerWidgetHeight: 50,
        searchInnerWidget: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4, right: 8, left: 8),
          child: TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              hintText: widget.searchHint,
              hintStyle: const TextStyle(fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
            ),
          ),
        ),
        searchMatchFn: (item, searchValue) {
          if (item.value == null) return false;
          final str = widget.itemAsString(item.value as T).toLowerCase();
          return str.contains(searchValue.toLowerCase());
        },
      ),
      onMenuStateChange: (isOpen) {
        if (!isOpen) {
          _searchController.clear();
        }
      },
    );

    if (widget.hideUnderline) {
      return DropdownButtonHideUnderline(child: dropdown);
    }
    return dropdown;
  }
}
