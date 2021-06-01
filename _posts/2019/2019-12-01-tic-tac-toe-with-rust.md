---
tags: ["rust"]
---

> **Disclaimer**: The solution bellow works, but there are many cut corners. This is because I am learning Rust. Don’t hesitate to improve my solution in the comments, or on [GitHub](https://github.com/plippe/tic-tac-toe-rust).

This isn’t [the first time]({{ site.baseurl }}{% post_url 2019/2019-01-01-taming-cats-state %}) I talk about [Tic Tac Toe](https://en.wikipedia.org/wiki/Tic-tac-toe). The game is a great way to familiarize oneself with variables, tests, loops, and functions. With all those elements it isn’t an easy project, but it isn’t hard either.

The simplest way to code this game is with a state machine.

## State Machine
First, the game starts. This is the best time to select the player that will begin and create an empty board. This leads to the next state where players take turns selecting an available cell on the board. This repeats until either a player wins or no available cell remains. This marks the end of the game.

```rust
pub enum State {
  StartGame,
  NextTurn(Player, Board),
  Won(Player),
  Draw,
  EndGame,
}

fn run(state: &State) -> State {
  match state {
    State::StartGame => unimplemented!(),
    State::NextTurn(player, board) => unimplemented!(),
    State::Won(player) => unimplemented!(),
    State::Draw => unimplemented!(),
    State::EndGame => unimplemented!(),
  }
}

fn main() {
  let mut state = State::StartGame;
  while state != State::EndGame {
    state = turn(&state);
  }
}
```

With the broad strokes explained above, most states are easy to define.

```rust
fn start_game() -> State {
  println!("Starting a new game");
  State::NextTurn(Player::first(), Board::new())
}

fn won(player: &Player) -> State {
  println!("Game finished and {:?} won", player);
  State::EndGame
}

fn draw() -> State {
  println!("Game finished with a draw");
  State::EndGame
}

fn end_game() -> State {
  println!("Game finished");
  State::EndGame
}
```

The only real complexity is around a player’s turn.

## NextTurn
A player’s turn starts by requesting and capturing their input.

For a game to be interactive players need to be able to submit information. In the case of Tic Tac Toe, players must select the cell they wish to mark. The game needs to guide them during that process like drawing the board.

```rust
use itertools::Itertools;
use std::collections::HashMap;

struct Board(HashMap<Coordinates, Player>)

impl ToString for Board {
  fn to_string(&self) -> String {
    let cell_size = 5;
    let line_split = vec!["-".repeat(cell_size); 3];

    (0..=3).map(|y| {
      (0..=3).map(move |x| {
        let cell_value = self.0
          .get(&Coordinates { x, y })
          .map_or(
            format!("{},{}", x, y),
            |player| format!("{:?}", player)
          );
        format!("{: ^1$}", cell_value, cell_size)
      })
      .collect()
    })
    .intersperse(line_split)
    .map(|row| row.join("|"))
    .join("\n")
  }
}
```

With the board visible, players are less likely to submit invalid inputs. Less likely means validation is still required.

```rust
use regex::Regex;
use std::str::FromStr;

#[derive(PartialEq, Eq, Clone, Hash)]
pub struct Coordinates {
  pub x: i8,
  pub y: i8,
}

impl FromStr for Coordinates {
  type Err = String;

  fn from_str(s: &str) -> Result<Self, Self::Err> {
    Regex::new(r"^(-?[0-9]+),(-?[0-9]+)$")
      .unwrap()
      .captures(s)
      .and_then(|cap| {
        let x = cap.get(1).and_then(|m| m.as_str().parse().ok());
        let y = cap.get(2).and_then(|m| m.as_str().parse().ok());

        match (x, y) {
          (Some(x), Some(y)) => Some((x, y)),
          _ => None,
        }
      })
      .map(|(x, y)| Coordinates { x, y })
      .ok_or("Coordinates can't be parsed".to_string())
  }
}

impl Board {
  pub fn insert(
    &self,
    coordinates: &Coordinates,
    player: &Player,
  ) -> Result<Board, String> {
    if coordinates.x < 0 || coordinates.x > 3 ||
        coordinates.y < 0 || coordinates.y > 3 {
      Err("Out of bounds".to_string())
    } else if self.0.contains_key(coordinates) {
      Err("Already defined".to_string())
    } else {
      let mut hash = self.0.clone();
      hash.insert(coordinates.clone(), player.clone());

      Ok(Board(hash))
    }
  }
}
```

Before moving to the next player, the updated board needs to be checked for win conditions. On a small board, like Tic Tac Toe, hard coding the rows, columns, and diagonals to check is a quick and dirty solution.

```rust
impl Board {
  pub fn is_won(&self) -> bool {
    let get = |x: i8, y: i8| self.hash.get(&Coordinates{x: 0, y:0});

    vec![
      (get(0, 0), get(0, 1), get(0, 2)),
      (get(1, 0), get(1, 1), get(1, 2)),
      (get(2, 0), get(2, 1), get(2, 2)),

      (get(0, 0), get(1, 0), get(2, 0)),
      (get(0, 1), get(1, 1), get(2, 1)),
      (get(0, 2), get(1, 2), get(2, 2)),

      (get(0, 0), get(1, 1), get(2, 2)),
      (get(0, 2), get(1, 1), get(2, 0)),
    ]
    .iter()
    .flat_map(|abc| match abc {
      (Some(a), Some(b), Some(c)) => Some((a, b, c)),
      _ => None,
    })
    .any(|(a, b, c)| a == b && b == c)
  }

  pub fn is_draw(&self) -> bool {
    self.hash.len() == 9
  }
}
```

By composing everything described above, we can write a function to handle `NextTurn`.

```rust
fn next_turn(player: &Player, board: &Board) -> State {
  println!("Player {:?}'s turn", player);
  println!("{}", board.to_string());
  println!("");
  println!("Where would you like to play?");

  read_input::<Coordinates>()
    .and_then(|coordinates| board.insert(&coordinates, &player))
    .map(|new_board|
      if new_board.is_won() { State::Won(player.clone()) }
      else if new_board.is_draw() { State::Draw }
      else { State::NextTurn(player.next(), new_board) }
    )
    .unwrap_or_else(|e| {
      println!("Error: {}", e);
      println!("Try again?");
      match read_input::<bool>().unwrap_or(false) {
        true => State::NextTurn(player.clone(), board.clone()),
        false => State::EndGame,
      }
    })
}
```

This completes the Tic Tac Toe game, but could it be better?

## M, n, k-game
Tic Tac Toe is an m, n, k-game. M refers to the number of rows, n the number of columns, and k the number of marks needed to win. Other m, n, k-game exist, like [Gomoku](https://en.wikipedia.org/wiki/Gomoku).

```rust
pub struct Game {
  pub min_x: i8,
  pub max_x: i8,
  pub min_y: i8,
  pub max_y: i8,
  pub goal: i8,
}

impl Game {
  pub const TIC_TAC_TOE: Game = Game {
    min_x: -1,
    max_x: 1,
    min_y: -1,
    max_y: 1,

    goal: 3,
  };

  pub const GOMOKU: Game = Game {
    min_x: -7,
    max_x: 7,
    min_y: -7,
    max_y: 7,

    goal: 5,
  };
}
```

Changing our game to handle any board size and winning constraint isn’t hard. Most of the functions above are already compatible. Those that need the most attention are in the `Board`’s implementation.

Taking the `ToString` implementation as an example. The hard coded `cell_size` needs to handle any x and y. Similarly, `line_split` must use the number of columns instead of 3. Lastly, the ranges are no longer between 0 and 3.

Instead of detailing [my solution](https://github.com/plippe/tic-tac-toe-rust), I will let you come up with yours. You shouldn’t have any issues writing your m, n, k-game. It can take a few hours, especially to identify if a player won, but you can do it.

---

I greatly enjoyed building this little game. It was just the right size to stay enjoyable. I will definitely build more games in the future. Possibly Chess, Poker, or Yahtzee. Any preference?
