## Run the container

```
docker compose up -d
```

## Pull the model

```
docker exec -it ollama ollama pull qwen3:8b
```

## Set the model context window. The doc suggests siomething between 10K and 30K

```
$ docker compose exec ollama bash
$ ollama run qwen3:8b
>>> /set parameter num_ctx 16384
Set parameter 'num_ctx' to '16384'
>>> /save qwen3:8b-16k
Created new model 'qwen3:8b-16k'
>>> /bye
```
