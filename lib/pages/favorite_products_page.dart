import 'package:flutter/material.dart';
import 'package:wasel/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritePage extends StatefulWidget {
  final List<Product> allProducts;
  final List<int> initialFavorites;

  FavoritePage({
    required this.allProducts,
    required this.initialFavorites,
  });

  

  @override
  _FavoritePageState createState() => _FavoritePageState();
}



class _FavoritePageState extends State<FavoritePage> {
  late List<int> _favoriteIds;

  @override
  void initState() {
    super.initState();
    _favoriteIds = List.from(widget.initialFavorites);
  }

  Future<void> _removeFavorite(int productId) async {
    setState(() {
      _favoriteIds.remove(productId);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'favoriteProductIds',
      _favoriteIds.map((id) => id.toString()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = widget.allProducts
        .where((product) => _favoriteIds.contains(product.id))
        .toList();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _favoriteIds);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Your Favorites'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _favoriteIds),
          ),
        ),
        body: favorites.isEmpty
            ? Center(
                child: Text(
                  'No favorites yet',
                  style: TextStyle(fontSize: 18),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final product = favorites[index];
                  return Dismissible(
                    key: Key(product.id.toString()),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _removeFavorite(product.id),
                    child: Card(
                      child: ListTile(
                        leading: Image.network(
                          product.image.startsWith('http')
                              ? product.image
                              : 'http://192.168.43.181:8000/storage/${product.image}',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        
                        title: Text(product.name),
                        subtitle: Text('\$${product.price}'),
                        trailing: IconButton(
                          icon: Icon(Icons.favorite, color: Colors.red),
                          onPressed: () => _removeFavorite(product.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}