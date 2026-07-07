# computercraft-twitchchat
Display twitch chat onto a monitor in minecraft using computer craft! Feel free to use this repo however you like.
# How it works

Essentially, twitch chat is just IRC over a websocket, and CC:Tweaked supports it directly so there is no need for an OAuth token or anything as we are only reading chat and not posting anything (might eventually add a feature? who knows)

What it does is:

Open a websocket to wss://irc-ws.chat.twitch.tv:443

Send an anonymous login 

Join a streamers channel (which you choose inside of the terminal)

recieve messages, parse out users, and print to monitors

Occassionally responds to Twitch's periodic pings so you aren't disconnected

# Current functionality

- Choose a channel to view the chat for

- Moderators and Subscribers have a green "M" or purple "S" by their names

- Matches a users chat colour as close as possible to a colour in a 13 long list (omitted black, grey, and brown due to visibility and also still working on weighted hex distances since the colours were being a bit off)

- Auto displays on a connected monitor

- Easy changing between channels and stopping


# Known bugs
- the colours are very iffy, e.g. a custom purple (very dark) can be matched to a red or brown (which is why i got rid of brown) but i'm working on a way to fix it.
