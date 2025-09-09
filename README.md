  ```powershell
  docker --version
  ```

  ```powershell
  node -v
  npm -v
  ```

---



Baseline (Dockerfile initial)

### 3.1 Mesure du temps de build

```powershell
Measure-Command { docker build -t app:baseline . }
```

**Résultat (extrait) :**

```
TotalSeconds : 64,9372912
# ≈ 1 min 05 s
```

### 3.2 Exécution locale

Application servie sur **localhost:3000** :

```
<div>Hello world — serveur volontairement non optimisé mais fonctionnel</div>
```

### 3.3 Métadonnées & taille d’image

```powershell
docker images | findstr app
docker history app:baseline
```

**Sortie :**

```
app    baseline   …   …   1.73GB
```

**Constat baseline** : image très lourde (\~1.73 GB), build lent (\~65 s).

### 3.4 Nettoyage baseline

```powershell
docker stop app-baseline
docker rmi app:baseline
```

---

## 4) Vérification applicative (Node.js en local)

Installation des dépendances :

```powershell
npm ci
```

Test de run local :

```
<div>Hello world — serveur volontairement non optimisé mais fonctionnel</div>
```

---

## 5) Dockerfile optimisé (multi-stage)

> On conserve l’ancien sous un autre nom (`Dockerfile_old`) et on crée un **Dockerfile** optimisé en deux étapes : **builder** puis **runner** léger.

```dockerfile
# ---------- Étape 1 : build ----------
FROM node:22-alpine AS builder

# Logs npm plus silencieux + pas de CI interactive
ENV NODE_ENV=production CI=true NPM_CONFIG_LOGLEVEL=warn

WORKDIR /app

# Tirer parti du cache pour les deps
COPY package*.json ./

# Dépendances prod uniquement, installation déterministe
RUN npm ci --omit=dev --no-audit --no-fund

# Copier le reste du projet
COPY . .

# (si build front/TS) construire ; sinon laisser tel quel
# RUN npm run build

# ---------- Étape 2 : run ----------
FROM node:22-alpine AS runner

ENV NODE_ENV=production
WORKDIR /app

# User non-root (sécurité)
RUN addgroup -S appgrp && adduser -S app -G appgrp

# Copier uniquement l’essentiel depuis le builder
COPY --from=builder /app/. /app

EXPOSE 3000
USER app
CMD ["node", "server.js"]
```

> **Pourquoi ça aide :**
>
> * `node:22-alpine` : base légère → taille réduite.
> * `npm ci --omit=dev` : pas de devDeps dans l’image → plus petit, plus rapide, reproductible.
> * split **builder/runner** : on n’embarque pas d’outils de build dans l’image finale.
> * **USER non-root** : durcit un minimum la surface d’attaque.

> node_modules
> npm-debug.log
> .git
> .gitignore
> ```

---

## 6) Mesures après optimisation

### 6.1 Build initial (builder + runner)

```powershell
Measure-Command { docker build -t app:opt . }
```

**Résultat :**

```
TotalSeconds : 18,2585146
# ≈ 18 s
```

### 6.2 Rebuild après petit changement (server.js)

Modification :

```js
// avant
res.send('Hello world — serveur volontairement non optimisé mais fonctionnel');
// après
res.send('Hello world — serveur optimisé et fonctionnel');
```

Re-build mesuré :

```
TotalSeconds : 5,4882548
# ≈ 5 s
```

### 6.3 Taille de l’image finale

```powershell
docker images | findstr app:opt
```

**Sortie :**

```
REPOSITORY   TAG   IMAGE ID        CREATED         SIZE
app          opt   f3f02879367d    4 minutes ago   244MB
```

### 6.4 Run optimisé

```powershell
docker run -d --rm -p 3000:3000 --name app-opt app:opt
```

Test : ouvrir **[http://localhost:3000](http://localhost:3000)**
Sortie attendue :

```
<div>Hello world — serveur optimisé et fonctionnel</div>
```

---

## 7) Comparatif avant / après

| Critère        | Baseline (initial) | Optimisé (final)   |
| -------------- | ------------------ | ------------------ |
| Temps de build | \~65 s             | \~18 s (1er build) |
| Rebuild        | —                  | \~5 s (modif code) |
| Taille image   | \~1.73 GB          | \~244 MB           |
| Sécurité       | root               | user non-root      |
| Base image     | node\:latest (?)   | node:22-alpine     |

**Synthèse :**

* **Taille** : −85% environ (1.73 GB → 244 MB).
* **Temps** : build initial \~3.5× plus rapide ; rebuilds très rapides grâce au cache et à `npm ci`.
* **Sécurité** : exécution en **non-root**.
* **Bonne pratique** : séparer build et run (multi-stage), limiter le contexte (`.dockerignore`), éviter devDeps en prod.

---

## 8) Journal de commandes (extraits)

```powershell
# Baseline
Measure-Command { docker build -t app:baseline . }
docker images | findstr app
docker history app:baseline
docker run -d --rm -p 3000:3000 --name app-baseline app:baseline
docker stop app-baseline
docker rmi app:baseline

# Optimisation
Measure-Command { docker build -t app:opt . }    # ~18 s
# (modif server.js)
Measure-Command { docker build -t app:opt . }    # ~5 s

docker run -d --rm -p 3000:3000 --name app-opt app:opt
docker images | findstr app:opt
```

---

## 9) Annexes (TP1)

* Lister les conteneurs / images :

  ```powershell
  docker ps -a
  docker images
  ```
* Supprimer conteneur / image :

  ```powershell
  docker stop <container>
  docker rm <container>
  docker rmi <image>
  ```
* Nettoyage (avancé) :

  ```powershell
  docker system prune -f
  ```

---

### Conclusion

Les optimisations appliquées (base **alpine**, **`npm ci --omit=dev`**, **multi-stage**, **non-root**) apportent un **gros gain de taille** et **des builds/rebuilds plus rapides**, tout en respectant les contraintes du TP. 
---
