"""
PROJET NOZ - UNE SEULE COMMANDE POUR TOUT REFAIRE

Ce script refait tout le projet, dans l'ordre, a partir des fichiers CSV :
  1. cree la base "noz" si elle n'existe pas ;
  2. lance les fichiers SQL 01, 02, 04 et 05 (tables, chargement, controles, vues) ;
  3. execute les 3 notebooks du debut a la fin (tests, modele RVN, prevision du CA).

Utilisation (dans un terminal ouvert dans ce dossier) :
    python lancer_tout.py

Le script demande le mot de passe de l'utilisateur PostgreSQL "postgres".
Il ne l'enregistre nulle part.

03_verifications.sql n'est pas lance : il contient 4 insertions fausses
faites expres pour montrer que la base les refuse (il s'arrete donc en erreur).
"""
import getpass
import glob
import os
import shutil
import subprocess
import sys

from sqlalchemy import URL

HOTE = os.environ.get("PGHOST", "localhost")
PORT = os.environ.get("PGPORT", "5432")
UTILISATEUR = os.environ.get("PGUSER", "postgres")
BASE = "noz"
FICHIERS_SQL = ["01_schema.sql", "02_charger_donnees.sql",
                "04_controles_qualite.sql", "05_vues_indicateurs.sql"]
NOTEBOOKS = ["06_tests_hypotheses.ipynb", "07_modele_rvn.ipynb", "08_prevision_ca.ipynb"]


def trouver_psql():
    """Cherche psql dans le PATH, puis dans le dossier d'installation habituel sous Windows."""
    chemin = shutil.which("psql")
    if chemin:
        return chemin
    candidats = sorted(glob.glob(r"C:\Program Files\PostgreSQL\*\bin\psql.exe"), reverse=True)
    if candidats:
        return candidats[0]
    sys.exit("psql introuvable : installe PostgreSQL ou ajoute son dossier bin au PATH.")


def psql(*arguments, base=BASE):
    commande = [PSQL, "-h", HOTE, "-p", PORT, "-U", UTILISATEUR, "-d", base,
                "-v", "ON_ERROR_STOP=1", *arguments]
    resultat = subprocess.run(commande, capture_output=True, text=True, encoding="utf-8")
    if resultat.returncode != 0:
        print(resultat.stdout)
        sys.exit(f"Erreur PostgreSQL :\n{resultat.stderr}")
    return resultat.stdout


# On travaille toujours depuis le dossier du projet (les chemins des CSV sont relatifs).
os.chdir(os.path.dirname(os.path.abspath(__file__)))
PSQL = trouver_psql()

mot_de_passe = os.environ.get("PGPASSWORD") or getpass.getpass("Mot de passe PostgreSQL : ")
os.environ["PGPASSWORD"] = mot_de_passe   

print("1. Base de donnees")
existe = psql("-Atc", f"SELECT 1 FROM pg_database WHERE datname = '{BASE}'", base="postgres")
if existe.strip() != "1":
    psql("-c", f"CREATE DATABASE {BASE} ENCODING 'UTF8' TEMPLATE template0", base="postgres")
    print(f"   base {BASE} creee")

print("2. Fichiers SQL")
for fichier in FICHIERS_SQL:
    sortie = psql("-f", fichier)
    print(f"   {fichier} : OK")
    if fichier.startswith("04"):
        nb_ok = sortie.count("| OK")
        print(f"   controles de qualite : {nb_ok} OK sur 22")
        if nb_ok != 22:
            print(sortie)
            sys.exit("Un controle de qualite a echoue : on s'arrete.")

print("3. Notebooks (quelques minutes)")
# Les notebooks lisent cette adresse au lieu de redemander le mot de passe.
if "NOZ_DB_URL" not in os.environ:
    os.environ["NOZ_DB_URL"] = URL.create(
        "postgresql+psycopg2", username=UTILISATEUR, password=mot_de_passe,
        host=HOTE, port=int(PORT), database=BASE).render_as_string(hide_password=False)
for notebook in NOTEBOOKS:
    subprocess.run([sys.executable, "-m", "jupyter", "nbconvert", "--to", "notebook",
                    "--execute", "--inplace", notebook], check=True)
    print(f"   {notebook} : OK")

print("\nTermine. Les graphiques sont dans figures/, les previsions dans previsions_7j.csv.")
