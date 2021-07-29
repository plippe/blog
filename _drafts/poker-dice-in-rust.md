# Poker dice with Rust
Poker dice is, as you would expect, a dice game that resembles poker. Players take turns throwing five dice aiming to roll the highest ranking combination. They have three attempts where they can reroll as many dice as they wish.

Implementing this simple game is a great way to practice any programming language. Below is my attempt at a Rust version. To start, I model the universe. Then, I implement a state machine to represent the game flow. Finally, I allow players to interact with the game via the command-line.

## Universe
The obvious first element to represent is a die. 

The version of poker dice I will implement is played with six-faced dice. Faces represent the top cards without their suit.

```rust
enum Die {
  Nine,
  Ten,
  Jack,
  Queen,
  King,
  Ace,
}
```

Next, I can implement hands. 

Poker has 10 different hands. They range from highest card to Royal flush. Poker-dice, without suits, can't support certain hands.

Ranking hands depend on their type, but also the dice that compose them. Capturing all relevant pieces of information is crucial to identify the best hand.

```rust
enum Hand {
  Bust {
    first: Die,
    second: Die,
    third: Die,
    fourth: Die,
    fifth: Die,
  },
  Pair { pair: Die, third: Die, fourth: Die, fifth: Die },
  TwoPair { pair1: Die, pair2: Die, fifth: Die },
  ThreeOfAKind { kind: Die, fourth: Die, fifth: Die },
  Straight { die: Die },
  FullHouse { three_of_a_kind: Die, pair: Die },
  FourOfAKind { kind: Die, fifth: Die },
  FiveOfAKind { kind: Die },
}
```

Ord type class
Explicit implémentation
Dérivéd one

Code

Derived based on order
Testing implementation to increase confidence

Code

State

Representing a dice
Representing winning hands
Representing turn state
The game as a command-line interface
