import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDirectory = await getApplicationDocumentsDirectory();
  HiveStore.init(onPath: appDocumentDirectory.path);

  final data = await HiveStore.openBox('box');
  ValueNotifier<GraphQLClient>? client;

  if (data.isOpen) {
    client = ValueNotifier(
      GraphQLClient(
        link: AuthLink(getToken: () async {
          {
            return "Bearer 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";
          }
        }).concat(HttpLink("https://api.github.com/graphql")),
        cache: GraphQLCache(store: HiveStore(data)),
      ),
    );
  }

  runApp(MyApp(client: client));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.client});

  final ValueNotifier<GraphQLClient>? client;

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: client,
      child: MaterialApp(
        title: 'Github Login',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(title: 'Github Login'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final loginTextController = TextEditingController();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  late Future<String> _loginText;
  @override
  void dispose() {
    loginTextController.dispose();
    super.dispose();
  }

  Future<void> _saveLogin() async {
    final SharedPreferences prefs = await _prefs;
    final String loginText = loginTextController.text;

    setState(() {
      _loginText = prefs.setString('loginText', loginText).then((bool success) {
        return loginText;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _loginText = _prefs.then((SharedPreferences prefs) {
      return prefs.getString('loginText') ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: TextField(
                controller: loginTextController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Login',
                ),
              )),
          Center(
            child: TextButton(
              onPressed: (() {
                _saveLogin();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SecondScreen(login: _loginText)),
                );
              }),
              child: const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }
}

class SecondScreen extends StatefulWidget {
  const SecondScreen({super.key, this.login});
  final Future<String>? login;

  @override
  State<SecondScreen> createState() => _SecondScreen();
}

class _SecondScreen extends State<SecondScreen> {
//   String readyProfileQuery(String? login) {
//   return """
//     query Flutter_Github_GraphQL{
//             user(login:"$login") {
//                 avatarUrl(size: 200)
//                 location
//                 name
//                 url
//                 email
//                 login
//                 bio
//                 repositories {
//                   totalCount
//                 }
//                 followers {
//                   totalCount
//                 }
//                 following {
//                   totalCount
//                 }
//               }
//           }
//       """;
// }

  String readProfileAndReposQuery(String? login) {
    return """
    query Flutter_Github_GraphQL{
            user(login:"$login") {
                avatarUrl(size: 200)
                bio
              },
                  viewer {
      repositories(last:10) {
        nodes {
          id
          name
          viewerHasStarred
        }
      }
    }
          }
      """;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Route'),
      ),
      body: Column(children: [
        FutureBuilder<String>(
            future: widget.login,
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.waiting:
                  return const CircularProgressIndicator();
                default:
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    return Query(
                      options: QueryOptions(
                          document:
                              gql(readProfileAndReposQuery(snapshot.data)),
                          pollInterval: const Duration(seconds: 10),
                          fetchPolicy: FetchPolicy.noCache),
                      builder: (QueryResult result,
                          {VoidCallback? refetch, FetchMore? fetchMore}) {
                        if (result.hasException) {
                          return Text(result.exception.toString());
                        }

                        if (result.isLoading) {
                          return const Text('Loading');
                        }
                        print(result.data!['user']['bio'] ?? "user not found");
                        print(result.data!['user']['avatarUrl'] ??
                            "user not found");
                        return Text(result.data!['user']['avatarUrl'] ??
                            "user not found");
                      },
                    );
                  }
              }
            })
      ]),
    );
  }
}
