class DrawerItem {
  DrawerItem({required this.title, required this.route, this.children});
  final String title;
  final String route;
  final List<DrawerItem>? children;
}
