# Rollup node simple deployment

##1. What it is

This code is made of a [docker-compose](https://docs.docker.com/compose/) file which will launch an [octez node](https://tezos.gitlab.io/introduction/howtouse.html) and a [Smart Optimistic Rollup node](https://tezos.gitlab.io/alpha/smart_rollups.html) in order to make you able to easily start an experiment on this infrastructure.

The rollup node will listen on [localhost:4545](http://localhost:4545) waiting for RPC calls

This code will not create any rollup or key on the Layer one tezos chain

I would suggest you to read the article [Setting up a Tezos Smart Rollup in 5 steps](https://news.tezoscommons.org/setting-up-a-tezos-smart-rollup-in-5-steps-af62ed75a684), or the [official documentation](https://tezos.gitlab.io/alpha/smart_rollups.html) if you need to create a rollup

##2. Prerequisites



Copy your octez node _datadir_, rollup node _datadir_ and client _base dir_ in the _data_ folder with the following names :
```
data
  |__client
  |__node
  |__smartrollup
```

Please edit the `.env` file and add your rollup _alias_ and _operator_ :
```
COMPOSE_FILE=docker-compose.yml
 
SOR_ALIAS_OR_ADDR=
OPERATOR_ADDR=
```

##3. Running it

run `docker-compose -p rollup up -d` in your terminal
