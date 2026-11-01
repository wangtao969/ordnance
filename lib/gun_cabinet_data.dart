/// 我的枪柜数据：个人档案（字段全部可空）+ 配件装机记录。
/// 拥有状态复用收藏柜 CollectionItem.status == 'owned'，不另起一套拥有体系；
/// 射弹数直接读收藏柜 rounds，不在这里另存；勋章逻辑不动。

class GunProfile {
  String gunName;
  String purchaseDate; // '' = 未填
  String price; // '' = 未填，自由文本
  String zeroStatus; // '' = 未填
  String maintenanceNote; // '' = 未填
  String faultNote; // '' = 未填

  GunProfile({
    required this.gunName,
    this.purchaseDate = '',
    this.price = '',
    this.zeroStatus = '',
    this.maintenanceNote = '',
    this.faultNote = '',
  });

  Map<String, dynamic> toJson() => {
        'gunName': gunName,
        'purchaseDate': purchaseDate,
        'price': price,
        'zeroStatus': zeroStatus,
        'maintenanceNote': maintenanceNote,
        'faultNote': faultNote,
      };

  factory GunProfile.fromJson(Map<String, dynamic> j) => GunProfile(
        gunName: j['gunName'] as String? ?? '',
        purchaseDate: j['purchaseDate'] as String? ?? '',
        price: j['price'] as String? ?? '',
        zeroStatus: j['zeroStatus'] as String? ?? '',
        maintenanceNote: j['maintenanceNote'] as String? ?? '',
        faultNote: j['faultNote'] as String? ?? '',
      );
}

class GunMount {
  /// 配件标识：取配件目录名（目录内唯一）；手动登记的配件同样用名标识。
  String accessoryId;
  String gunName;
  int mountDateMs;

  GunMount({
    required this.accessoryId,
    required this.gunName,
    required this.mountDateMs,
  });

  Map<String, dynamic> toJson() => {
        'accessoryId': accessoryId,
        'gunName': gunName,
        'mountDateMs': mountDateMs,
      };

  factory GunMount.fromJson(Map<String, dynamic> j) => GunMount(
        accessoryId: j['accessoryId'] as String? ?? '',
        gunName: j['gunName'] as String? ?? '',
        mountDateMs: (j['mountDateMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
}
