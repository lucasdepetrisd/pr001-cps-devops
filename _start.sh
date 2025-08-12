#!/bin/sh

echo "Waiting for Postgres to be ready..."
until pg_isready -h postgres -p 5432; do
  echo "Postgres is not ready yet. Sleeping..."
  sleep 2
done

echo "Running migrations..."
npm run prisma:migrate

echo "Running seeds..."
npm run prisma:seed:all

echo "Starting backend application..."
npm start
