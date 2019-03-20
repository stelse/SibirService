CREATE DATABASE my_service;
\c my_service;

CREATE TABLE IF NOT EXISTS persons (id SERIAL PRIMARY KEY UNIQUE, login TEXT NOT NULL UNIQUE, pass TEXT NOT NULL, role TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS tasks (id SERIAL UNIQUE, description TEXT NOT NULL, phrase TEXT, id_person INTEGER NOT NULL, PRIMARY KEY (id, id_person), CONSTRAINT tasks_persons_id_persons_fkey FOREIGN KEY(id_person) REFERENCES persons(id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE);

CREATE TABLE IF NOT EXISTS tests (id SERIAL UNIQUE, id_task INTEGER NOT NULL, input TEXT NOT NULL, output TEXT NOT NULL, PRIMARY KEY (id, id_task), CONSTRAINT tests_tasks_id_tasks_fkey FOREIGN KEY(id_task) REFERENCES tasks(id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE);

CREATE TABLE IF NOT EXISTS assigned_tasks (id SERIAL UNIQUE, id_person INTEGER NOT NULL, id_task INTEGER NOT NULL, PRIMARY KEY (id, id_person, id_task), CONSTRAINT assigned_tasks_persons_id_person_fkey FOREIGN KEY(id_person) REFERENCES persons(id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE, CONSTRAINT tasks_assigned_tasks_id_tests_fkey FOREIGN KEY (id_task) REFERENCES tasks(id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE);

CREATE TABLE IF NOT EXISTS fingerprints (id SERIAL UNIQUE, id_assigned_task INTEGER NOT NULL, date TEXT NOT NULL, uniqueness REAL NOT NULL, fingerprint TEXT NOT NULL, PRIMARY KEY (id, id_assigned_task), CONSTRAINT fingerprint_assigned_tasks_id_assigned_task_fkey FOREIGN KEY(id_assigned_task) REFERENCES assigned_tasks(id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE);

CREATE TABLE IF NOT EXISTS fingerprint_fingerprint (id SERIAL, id_fingerprint INTEGER NOT NULL, id_fingerprint_for_comparison INTEGER NOT NULL, PRIMARY KEY (id, id_fingerprint, id_fingerprint_for_comparison), CONSTRAINT fingerprints_fingerprint_fingerprint_id_fingerprint_fkey FOREIGN KEY(id_fingerprint) REFERENCES fingerprints(id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE, CONSTRAINT fingerprints_fingerprint_fingerprint_id_fingerprint_for_comparison_fkey     FOREIGN KEY(id_fingerprint_for_comparison) REFERENCES fingerprints(id) MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE);
