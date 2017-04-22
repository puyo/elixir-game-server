# Elixir Camp 2017

- Word and board game server w/ multiple types of games available
- Chat rooms
- Expand on Phoenix / Elm chat app example
- Plan game states and messages
- Persistent storage optional - maybe once a game has finished,
  keep a record of it
- Each game is a separate Elm app, but some shared .elm code for
  generic chat functionality if possible


## GAME CHAT ROOMS

Useful for all kinds of games.

  GET /
    List of named chat rooms

  POST /room
    name = "room name", game type = "poetry"

  GET /room/abc123
    Dedicated channel / room
    Serves elm app
    Websocket connection back to phoenix server
    

## POETRY GAME (low complexity)

A writing prompt game for poetic types I used to play a lot at university

- 3-100 players
- Simultaneous play
- Each player submits a random word and a random question, then
  writes a poem using the random words and questions that the
  other players submitted
- In jokes and bad poems created
- Optionally save/share funny results

  visualisation
  
    like the real life version, viewed from above
    outer circle of players seated, spread evenly
    inner circle of pieces of paper, generally 1 per player but sometimes queued up in front of them if they are slow to take their turn

  client states

    user not playing (initial state)
    user ready to play
    user writing word
    user writing question
    user writing poem
    user reading results
    
  game model
    
    users
      - unique player / author id
      - state (ready, etc.)

    papers
      - word
      - word author id (init)
      - question
      - question author id (init)
      - poem
      - poem author id (init)

   client -> server:
     i am ready to play
     here is my word (paper id, word)
     here is my question (paper id, question)
     here is my poem (paper id, poem)
     
   server -> client:
     user joined room
     user left room
     user state change (ready, name, etc.)
     chat
     paper updated (... new paper state ...)
     finished


## COUNTDOWN (medium complexity)

A ripoff of the BBC TV program Countdown (TM)

- 2-100 players
- Simultaneous play
- Round 1
  - Players are provided with the same 6 consonants and 4 vowels (randomly selected)
  - Players get 60 seconds to submit the longest English word they can make with the letters provided
  - The longest word (that is in the dictionary) wins
- Round 2
  - Players are provided two 3 digit numbers and four 1 digit numbers (randomly selected), and also one target 3 digit number
  - Players get 60 seconds to submit an equation using the random numbers provided that equals the target number or is as close to it as possible, using the 4 operators: + - * /
  
  

## DOMINION (high complexity)

The board game Dominion. God where to start. It's complicated.


## PICTORIAL CONSEQUENCES (high complexity)

Like the website Drawception but not really sure what I can add because it's already fabulous so skipping this for now.
