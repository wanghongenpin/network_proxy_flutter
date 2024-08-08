//获取list元素类型
Type getListElementType(dynamic list) {
  if (list == null || list.isEmpty || list is! List) {
    return Null;
  }

  var type = list.first.runtimeType;

  return type;
}

dynamic getFirstElement(List? list) {
  return list?.firstOrNull;
}

//转换指定类型
List<T> convertList<T>(List list) {
  return list.map((e) => e as T).toList();
}
