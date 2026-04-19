FROM python:3.12-alpine

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy collector scripts
COPY . .

# Cron schedule: run every 2 hours
RUN echo "0 */2 * * * cd /app && python3 /app/run_collect.py >> /var/log/collector.log 2>&1" > /etc/crontabs/root

# Keep cron in foreground
CMD ["crond", "-f", "-d", "8"]
