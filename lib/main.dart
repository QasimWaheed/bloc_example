import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:developer' as devtools show log;

extension Log on Object {
  void log() => devtools.log(toString());
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocProvider(
        create: (_) => PersonsBloc(),
        child: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home Page"),
      ),
      body: Column(
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () {
                  context.read<PersonsBloc>().add(
                        const LoadPersonAction(
                          url: PersonUrl.persons1,
                        ),
                      );
                },
                child: const Text("Load Json #1"),
              ),
              TextButton(
                onPressed: () {
                  context.read<PersonsBloc>().add(
                        const LoadPersonAction(
                          url: PersonUrl.persons2,
                        ),
                      );
                },
                child: const Text("Load Json #2"),
              ),
            ],
          ),
          BlocBuilder<PersonsBloc, FetchResult?>(
            buildWhen: (previousResult, currentResult) {
              return previousResult?.persons != currentResult?.persons;
            },
            builder: (context, fetchResult) {
              fetchResult?.log();
              final persons = fetchResult?.persons;
              if (persons == null) {
                return const SizedBox();
              }
              return Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: persons.length,
                  itemBuilder: (context, index) {
                    final person = persons[index]!;
                    return ListTile(
                      title: Text(person.name),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

extension Subscript<T> on Iterable<T> {
  T? operator [](int index) => length > index ? elementAt(index) : null;
}

Future<Iterable<Person>> getPersons(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((res) => res.transform(utf8.decoder).join())
    .then((str) => json.decode(str) as List<dynamic>)
    .then((list) => list.map((e) => Person.fromJson(e)));

@immutable
class FetchResult {
  final Iterable<Person> persons;
  final bool isRetrievedFromCache;

  const FetchResult({
    required this.persons,
    required this.isRetrievedFromCache,
  });

  @override
  String toString() =>
      'FetchResult (isRetrievedFromCache = $isRetrievedFromCache, Persons = $persons)';
}

class PersonsBloc extends Bloc<LoadAction, FetchResult?> {
  final Map<PersonUrl, Iterable<Person>> _cache = {};

  PersonsBloc() : super(null) {
    on<LoadPersonAction>((event, emit) async {
      final url = event.url;
      if (_cache.containsKey(url)) {
        final cachedPersons = _cache[url]!;
        final result = FetchResult(
          persons: cachedPersons,
          isRetrievedFromCache: true,
        );
        emit(result);
      } else {
        final persons = await getPersons(url.urlString);
        _cache[url] = persons;
        final result = FetchResult(
          persons: persons,
          isRetrievedFromCache: false,
        );
        emit(result);
      }
    });
  }
}

@immutable
abstract class LoadAction {
  const LoadAction();
}

@immutable
class LoadPersonAction implements LoadAction {
  final PersonUrl url;

  const LoadPersonAction({required this.url}) : super();
}

@immutable
class Person {
  final String name;
  final int age;

  const Person({required this.name, required this.age});

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        name: json['name'],
        age: json['age'],
      );

  @override
  String toString() => 'Person (name = $name, age = $age';
}

enum PersonUrl { persons1, persons2 }

extension UrlString on PersonUrl {
  String get urlString {
    switch (this) {
      case PersonUrl.persons1:
        return 'http://10.0.2.2:5500/api/person1.json';
      case PersonUrl.persons2:
        return 'http://10.0.2.2:5500/api/person2.json';
    }
  }
}
