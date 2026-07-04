"""
Exercise 07 - Automate the creation of an Azure Database for PostgreSQL and
load data into it.

Uses psycopg2 to create the database, then sqlalchemy (ORM) to define a
single table based on the holiday_songs.csv schema, insert its rows with
the `add` method, and run sample queries (top songs, update position,
delete a song).

Requirements:
    pip install -r requirements.txt
"""

import os
import csv
from datetime import datetime

import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv
from sqlalchemy import create_engine, Column, Integer, String, Date
from sqlalchemy.orm import declarative_base, sessionmaker

load_dotenv()

PG_HOST = os.getenv("PG_HOST")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DATABASE = os.getenv("PG_DATABASE")
PG_ADMIN_LOGIN = os.getenv("PG_ADMIN_LOGIN")
PG_ADMIN_PASSWORD = os.getenv("PG_ADMIN_PASSWORD")

DATA_FILE = os.path.join(os.path.dirname(__file__), "data", "holiday_songs.csv")

Base = declarative_base()


class Song(Base):
    __tablename__ = "holiday_songs"

    id = Column(Integer, primary_key=True)
    year = Column(Integer, nullable=False)
    position = Column(Integer, nullable=False)
    song = Column(String(200), nullable=False)
    artist = Column(String(150), nullable=False)
    chart_date = Column(Date, nullable=False)

    def __repr__(self):
        return f"<Song {self.song!r} by {self.artist!r} (#{self.position}, {self.year})>"


def create_database():
    """Connect to the default 'postgres' db and create PG_DATABASE if it doesn't exist yet."""
    conn = psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        dbname="postgres",
        user=PG_ADMIN_LOGIN,
        password=PG_ADMIN_PASSWORD,
        sslmode="require",
    )
    conn.autocommit = True
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (PG_DATABASE,))
            if cursor.fetchone():
                print(f"Database {PG_DATABASE} already exists.")
            else:
                cursor.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(PG_DATABASE)))
                print(f"Database {PG_DATABASE} created.")
    finally:
        conn.close()


def get_engine():
    url = (
        f"postgresql+psycopg2://{PG_ADMIN_LOGIN}:{PG_ADMIN_PASSWORD}"
        f"@{PG_HOST}:{PG_PORT}/{PG_DATABASE}?sslmode=require"
    )
    return create_engine(url)


def load_songs(session):
    if session.query(Song).first():
        print("Skipping load: holiday_songs already has data.")
        return

    with open(DATA_FILE, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            session.add(
                Song(
                    id=int(row["index"]),
                    year=int(row["Year"]),
                    position=int(row["Position"]),
                    song=row["Song"],
                    artist=row["Artist"],
                    chart_date=datetime.strptime(row["Chart Date"], "%m/%d/%Y").date(),
                )
            )
    session.commit()
    print("Data inserted into holiday_songs.")


def get_top_songs(session, year, top_n=10):
    """Return the top N songs for a given year, ordered by chart position."""
    return (
        session.query(Song)
        .filter(Song.year == year)
        .order_by(Song.position.asc())
        .limit(top_n)
        .all()
    )


def update_song_position(session, song_id, new_position):
    """Update the chart position of a song by its id."""
    song = session.query(Song).filter(Song.id == song_id).first()
    if song is None:
        print(f"No song found with id={song_id}")
        return None
    song.position = new_position
    session.commit()
    print(f"Updated song id={song_id} to position {new_position}")
    return song


def delete_song(session, song_id):
    """Delete a song by its id."""
    song = session.query(Song).filter(Song.id == song_id).first()
    if song is None:
        print(f"No song found with id={song_id}")
        return
    session.delete(song)
    session.commit()
    print(f"Deleted song id={song_id} ({song.song})")


def main():
    print(f"Connecting to {PG_HOST}...")
    create_database()

    engine = get_engine()
    Base.metadata.create_all(engine)
    print("Table ready.")

    Session = sessionmaker(bind=engine)
    session = Session()

    load_songs(session)

    print("\nTop 5 songs of 2011:")
    for s in get_top_songs(session, year=2011, top_n=5):
        print(f"  #{s.position} {s.song} - {s.artist}")

    session.close()


if __name__ == "__main__":
    main()
