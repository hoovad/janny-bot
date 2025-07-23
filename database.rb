# frozen_string_literal: true

require 'sqlite3'

# DatabaseHandler
# Handles database operations (for use in janny-bot ONLY)
class DatabaseHandler
  def initialize
    @db = SQLite3::Database.new('database.db')
    @db.results_as_hash = true
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS bans (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL,
        until INTEGER
      );
    SQL
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS cases (
          id INTEGER PRIMARY KEY,
          username TEXT NOT NULL,
          cases TEXT NOT NULL
      );
    SQL
  end

  def add_ban(id, username, until_time = nil)
    @db.execute('INSERT INTO bans (id, username, until) VALUES (?, ?, ?)', [id, username, until_time])
  end

  def update_cases(id, username, cases)
    existing_cases = @db.get_first_value('SELECT cases FROM cases WHERE id = ?', [id])
    cases = JSON.generate(cases)
    if existing_cases
      @db.execute('INSERT INTO cases (id, username, cases) VALUES (?, ?, ?)', [id, username, cases])
    else
      @db.execute('UPDATE cases SET cases = ? WHERE id = ?', [cases, id])
    end
  end

  def get_cases(id: nil, username: nil)
    if id
      cases = @db.get_first_value('SELECT cases FROM cases WHERE id = ?', [id])
    elsif username
      cases = @db.get_first_value('SELECT cases FROM cases WHERE username = ?', [username])
    end
    if cases
      JSON.parse(cases)
    else
      cases
    end
  end

  def query_bans(id)
    @db.execute('SELECT * FROM bans WHERE id = ?', [id])
  end

  def delete_ban(id)
    @db.execute('DELETE FROM bans WHERE id = ?', [id])
  end
end
