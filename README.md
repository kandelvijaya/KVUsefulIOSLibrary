# KVUsefulIOSLibrary
This repo holds small libraries that i created while working on various projects. The intent of putting up these seperate files here is to simply offer a little bit of coding time saver.

Feel free to modify and use it as you like. I would love any contributions too.

1. KVDisatnceFromUser 
  This file can compute a distance of a certain geopoint which you are interested in from the devices or the user location. It does this silently without taking all the battery.
Uses significant change monitoring and caching the user location on NSUserDefaults for later usage.

2. ViewCounterIncrementParseDB
  This file helps increment the view count on the model entity like User, Game, MusicAlbum, Restaurant which are stored in Parse Cloud Server. The api stores the viewCount in offline if the user has no internet connection and then syncs that count whenever he is reachable to the internet. The race condition is also handled.
...todo..... change the column name to match your attribute header in db
