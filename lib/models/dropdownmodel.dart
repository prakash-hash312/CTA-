// dropdown_models.dart

class MenuItem {
  final int subMenuId;
  final int mainMenuId;
  final String mainMenuTitle;
  final String statusBar;
  final int menuOrder;
  final String routePath;

  MenuItem({
    required this.subMenuId,
    required this.mainMenuId,
    required this.mainMenuTitle,
    required this.statusBar,
    required this.menuOrder,
    this.routePath = '',
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    return MenuItem(
      subMenuId: json['sub_menu_id'] ?? 0,
      mainMenuId: json['main_menu_id'] ?? 0,
      mainMenuTitle: json['main_menu_title'] ?? 'N/A',
      statusBar: json['status_bar'] ?? 'N/A',
      menuOrder: json['menu_order'] ?? 0,
      routePath: readString([
        'route',
        'route_path',
        'router_link',
        'routerLink',
        'page_route',
        'pageRoute',
        'navigation_url',
        'navigate_url',
        'menu_url',
        'menu_link',
        'url',
        'path',
        'screen_name',
        'screen_route',
      ]),
    );
  }
}

class ThemeItem {
  final int themeId;
  final String theme;

  ThemeItem({required this.themeId, required this.theme});

  factory ThemeItem.fromJson(Map<String, dynamic> json) {
    return ThemeItem(
      themeId: json['theme_id'] ?? 0,
      theme: json['theme'] ?? 'Default',
    );
  }
}

class GenderItem {
  final String genderId;
  final String gender;

  GenderItem({required this.genderId, required this.gender});

  factory GenderItem.fromJson(Map<String, dynamic> json) {
    return GenderItem(
      genderId: json['gender_id'] ?? 'N/A',
      gender: json['gender'] ?? 'Unknown',
    );
  }
}

class StateItem {
  final int stateId;
  final String stateName;

  StateItem({required this.stateId, required this.stateName});

  factory StateItem.fromJson(Map<String, dynamic> json) {
    return StateItem(
      stateId: json['state_id'] ?? 0,
      stateName: json['state_name'] ?? 'N/A',
    );
  }
}
