#!/usr/bin/env python3
"""Seed/verify only the database pulled from the disposable validation AVD."""
import sqlite3
import sys

NAME = 'HMB validation synthetic customer'
DESCRIPTION = 'Preserve this synthetic record across the release upgrade'


def fixture(action, path):
    with sqlite3.connect(path) as db:
        if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Database integrity check failed')
        if action == 'seed':
            db.execute('''INSERT INTO customer
                (name, description, createdDate, modifiedDate, disbarred, customerType)
                VALUES (?, ?, ?, ?, 0, 0)''',
                (NAME, DESCRIPTION, '2026-01-01T00:00:00', '2026-01-01T00:00:00'))
            db.commit()
            db.execute('PRAGMA wal_checkpoint(TRUNCATE)')
        elif action == 'verify':
            rows = db.execute('SELECT description FROM customer WHERE name=?', (NAME,)).fetchall()
            if rows != [(DESCRIPTION,)]:
                raise ValueError('Synthetic customer was lost or changed during upgrade')
        else:
            raise ValueError('Expected seed or verify')
    print(f'PASS: {action} synthetic upgrade customer')


if __name__ == '__main__':
    fixture(*sys.argv[1:])
