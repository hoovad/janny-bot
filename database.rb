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
        id INTEGER PRIMARY KEY NOT NULL,
        username TEXT,
        until INTEGER,
        reason TEXT
      );
    SQL
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS cases (
          id INTEGER PRIMARY KEY NOT NULL,
          username TEXT,
          cases TEXT NOT NULL
      );
    SQL
  end

  def add_ban(id, username: nil, until_time: nil, reason: nil)
    existing_ban = @db.get_first_value('SELECT * FROM bans WHERE id = ?', [id])
    if existing_ban
      @db.execute('UPDATE bans SET username = ?, until = ?, reason = ? WHERE id = ?',
                  [username, until_time, reason, id])
    else
      @db.execute('INSERT INTO bans (id, username, until, reason) VALUES (?, ?, ?, ?)',
                  [id, username, until_time, reason])
    end
  end

  def update_cases(id, cases, username: nil)
    existing_cases = @db.get_first_value('SELECT * FROM cases WHERE id = ?', [id])
    cases = JSON.generate(cases)
    if existing_cases
      @db.execute('UPDATE cases SET cases = ?, username = ? WHERE id = ?', [cases, username, id])
    else
      @db.execute('INSERT INTO cases (id, username, cases) VALUES (?, ?, ?)', [id, username, cases])
    end
  end

  def get_cases(id: nil, username: nil)
    if id
      cases = @db.get_first_value('SELECT cases FROM cases WHERE id = ?', [id])
    elsif username
      cases = @db.get_first_value('SELECT cases FROM cases WHERE username = ?', [username])
    end
    return unless cases

    JSON.parse(cases)
  end

  def query_bans(id: nil, username: nil)
    if id
      @db.execute('SELECT * FROM bans WHERE id = ?', [id])
    elsif username
      @db.execute('SELECT * FROM bans WHERE username = ?', [username])
    end
  end

  def delete_ban(id: nil, username: nil)
    if id
      @db.execute('DELETE FROM bans WHERE id = ?', [id])
    elsif username
      @db.execute('DELETE FROM bans WHERE username = ?', [username])
    end
  end
end
