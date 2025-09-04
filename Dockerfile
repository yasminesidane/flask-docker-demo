# Image Python légère
FROM python:3.12-slim

# Répertoire de travail dans le conteneur
WORKDIR /app

# Installer les dépendances
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code
COPY . .

# Exposer le port de l'app
EXPOSE 5000

# Lancer l'app
CMD ["python", "app.py"]
