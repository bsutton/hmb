# Controlling Widget Rebuilds in Flutter: A Guide to Stateless and Stateful Widgets

Flutter's UI system is built around widgets, which are the building blocks of the application’s user interface. Understanding how to control widget rebuilds in Flutter is crucial for optimizing performance and ensuring a smooth user experience. This article explores how to manage widget rebuilds in both stateless and stateful widgets, as well as the role of the setState method in controlling these rebuilds.

The problem with Dart and widget rebuilds is that the offical guides and every blog that I've read on this issue is rather vauge about the how and when flutter decides to rebuild a widget and as dev I'm left with the feeling that its all magic under the hood, but of course its not.

So lets look at a few aspects and see if we can peel back the fog of war and get to a true understanding of how and why Flutter decides to rebuild a widget.

# setState

The core of controlling when a widget get's rebuild is setState.  setState has always puzzled me and its only recently that I've understood why. 

The why is that setState is a lie, a piece of social engineering by the Flutter team for you to use it sparingingly.

Let's have a look at setState and how we are taught to call it:

```dart
setState(() {
    somefield = newValue;
})
```

OK, so we must be doing this so flutter knows what has changed - nope its a lie.

The hint to the lie is that the closure that we pass to setState must be a synchronous
method and we are told that if we are making an async call then we must do it
outside the setState call.

When I first read this it really confused me. If the closure is telling flutter
what state has changed then how can we change the state for async values outside the
call to setState?

Well it works be setState actually does nothing with the closure except call it.
It doesn't care if it contains state change if fact the call to setState can be summarised as:

```dart
setState( void Function() callback)
{
    callback();
    _element!.markNeedsBuild();
}
```

The callback is completely irrelavant. You can rewrite above example as:

```dart
somefield = newValue;
setState(() {});
```

The only important bit is that any changes to you widget's state must be completed
before the call to setState.

So Flutter knows nothing about what state has changed it just knows that your
widget needs to be rebuilt.


My understanding was that Flutter team introduced setState because people were
calling `markNeedsBuild` too frequently and the setState method made it clearer
that you should only call markNeedsBuild when you widget state was changing.

This one did my head in for a long time because it made no sense.

# Stateless widgets - really do have state

So you probably understand that a Stateless widget is an immutable class
and all fields must be final.

But the name 'stateless' is somewhat misleading in the sense that a Stateless
widget does have state. The widgets state is encapsulated in the classes' set of field - it just can't be mutated from
within the class.

But..... it can a Stateless Wdiget can be recreated by the parent widget.

So let's make this a little more concrete.

```dart

Person contact;

void build(BuildContext context)
 => 
    ShowPersonWidget(contact);  
```







Stateless Widgets
Stateless widgets are immutable, meaning that once they are built, they cannot change. This immutability makes them efficient and easy to use when the widget's configuration does not change over time or in response to user interactions.

When Do Stateless Widgets Rebuild?
Stateless widgets rebuild when:

Parent widget rebuilds: If the parent widget of a stateless widget rebuilds, the stateless widget will also rebuild.
Dependencies change: If a widget's dependencies (inherited widgets) change, it may trigger a rebuild.
Controlling Rebuilds
To minimize unnecessary rebuilds, ensure that stateless widgets depend only on the data that will not change. Additionally, you can use widget keys to preserve the state of widgets between rebuilds when their positions in the widget tree change.

dart
Copy code
class MyStatelessWidget extends StatelessWidget {
  final String title;

  const MyStatelessWidget({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(title);
  }
}
In this example, MyStatelessWidget rebuilds only if its title property or its parent's configuration changes.

Stateful Widgets
Stateful widgets, on the other hand, can change dynamically over time. They maintain a mutable state object that can be updated, causing the widget to rebuild.

Understanding setState
The setState method is a critical part of stateful widgets. It notifies the framework that the internal state has changed and that the widget needs to be rebuilt.

dart
Copy code
class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({Key? key}) : super(key: key);

  @override
  _MyStatefulWidgetState createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Counter: $_counter'),
        ElevatedButton(
          onPressed: _incrementCounter,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
How setState Works
Marking dirty: When setState is called, it marks the widget as "dirty," indicating that it needs to rebuild.
Rebuild cycle: During the next build cycle, the framework calls the build method to rebuild the widget with the updated state.
Efficient updates: Only the widget marked as dirty and its descendants are rebuilt, not the entire widget tree.
Controlling Rebuilds in Stateful Widgets
Minimal setState calls: Call setState only when necessary and update only the part of the state that affects the UI.
Use shouldRebuild: When working with ListView.builder or other similar widgets, use shouldRebuild to control when child widgets should rebuild.
dart
Copy code
@override
bool shouldRebuild(covariant MyStatefulWidget oldWidget) {
  return oldWidget.data != data;
}
Separate logic and UI: Keep the state management logic separate from the UI code to prevent unnecessary rebuilds.
Conclusion
Understanding when and how widgets rebuild in Flutter is essential for building efficient applications. While stateless widgets rely on immutability, stateful widgets use the setState method to manage dynamic changes. By carefully managing rebuilds and minimizing unnecessary setState calls, you can optimize performance and provide a seamless user experience. Always aim to separate state management from UI concerns to maintain clean and efficient code.