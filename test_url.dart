void main() {
  String photoUrl = "https://lh3.googleusercontent.com/a/ACg8ocJKG4DkZB--GVkn52HDTZ2RPQGwPsnIG4dnBAaiayiylDE434fyaQ=s96-c";
  
  if (photoUrl.contains('googleusercontent.com')) {
    photoUrl = photoUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
  }

  if (photoUrl.startsWith('http') && !photoUrl.contains('wsrv.nl')) {
    photoUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(photoUrl)}';
  }
  print(photoUrl);
}
