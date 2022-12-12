import 'dart:typed_data';

Doors doors = Doors();
Door currentDoor = Door();

// ==========Doors==========

class Doors {

  Map<String, Door> _doors = {};


  void addDoor(Door door) {
    _doors[door.getName()] = door;
  }

  Door? getDoor(String name) {
    if(_doors.containsKey(name)){
      return _doors[name];
    }
    return null;
  }

  List<String> getAllDoorsList() {
    return List.of(_doors.keys);
  }
}

// ==========Doors==========

// ==========Door==========

class Door {

  String _name = "";
  String _secret = "";
  Uint8List _share1 = Uint8List.fromList(List.empty());

  List<String> _cover2s = List.empty(growable: true);
  List<String> _blackList = List.empty(growable: true);


  void setName(String name) {
    _name = name;
  }

  void setSecret(String secret) {
    _secret = secret;
  }

  void setShare1(Uint8List share1) {
    _share1 = share1;
  }

  String getName() {
    return _name;
  }

  String getSecret() {
    return _secret;
  }

  Uint8List getShare1() {
    return _share1;
  }

  bool isForbidden(String cover2) {
    return _blackList.contains(cover2);
  }

  void addCover2(String cover2) {
    _cover2s.add(cover2);
  }
}

// ==========Door==========