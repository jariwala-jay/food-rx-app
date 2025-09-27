#!/bin/bash

# Notification System Cloud Functions Deployment Script
# This script deploys the notification system to Google Cloud Functions

set -e

echo "🚀 Starting Notification System Deployment..."

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI is not installed. Please install it first:"
    echo "   curl https://sdk.cloud.google.com | bash"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Not authenticated with Google Cloud. Please run:"
    echo "   gcloud auth login"
    exit 1
fi

# Get project ID
PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo "❌ No project ID set. Please run:"
    echo "   gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo "📋 Project ID: $PROJECT_ID"

# Check if MongoDB URI is set
if [ -z "$MONGODB_URI" ]; then
    echo "⚠️  MONGODB_URI environment variable not set."
    echo "   Please set it with your MongoDB connection string:"
    echo "   export MONGODB_URI='mongodb://your-connection-string'"
    read -p "   Do you want to continue without MongoDB URI? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Deploy notification-scheduler function
echo "📦 Deploying notification-scheduler function..."
gcloud functions deploy notification-scheduler \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --source gcloud/functions/notification-scheduler \
  --memory 256MB \
  --timeout 540s \
  --set-env-vars MONGODB_URI="$MONGODB_URI" \
  --region us-central1

echo "✅ notification-scheduler deployed successfully"

# Deploy notification-delivery function
echo "📦 Deploying notification-delivery function..."
gcloud functions deploy notification-delivery \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --source gcloud/functions/notification-delivery \
  --memory 256MB \
  --timeout 540s \
  --set-env-vars MONGODB_URI="$MONGODB_URI" \
  --region us-central1

echo "✅ notification-delivery deployed successfully"

# Get function URLs
SCHEDULER_URL=$(gcloud functions describe notification-scheduler --region=us-central1 --format="value(httpsTrigger.url)")
DELIVERY_URL=$(gcloud functions describe notification-delivery --region=us-central1 --format="value(httpsTrigger.url)")

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Function URLs:"
echo "   Scheduler: $SCHEDULER_URL"
echo "   Delivery:  $DELIVERY_URL"
echo ""

# Set up Cloud Scheduler jobs
echo "⏰ Setting up Cloud Scheduler jobs..."

# Enable Cloud Scheduler API
gcloud services enable cloudscheduler.googleapis.com

# Create morning notifications job
echo "   Creating morning notifications job..."
gcloud scheduler jobs create http morning-notifications \
  --schedule="0 8 * * *" \
  --uri="$SCHEDULER_URL" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"type":"morning"}' \
  --time-zone="America/New_York" \
  --description="Morning health notifications at 8 AM" || echo "   Morning job may already exist"

# Create afternoon notifications job
echo "   Creating afternoon notifications job..."
gcloud scheduler jobs create http afternoon-notifications \
  --schedule="0 14 * * *" \
  --uri="$SCHEDULER_URL" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"type":"afternoon"}' \
  --time-zone="America/New_York" \
  --description="Afternoon health notifications at 2 PM" || echo "   Afternoon job may already exist"

# Create evening notifications job
echo "   Creating evening notifications job..."
gcloud scheduler jobs create http evening-notifications \
  --schedule="0 20 * * *" \
  --uri="$SCHEDULER_URL" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"type":"evening"}' \
  --time-zone="America/New_York" \
  --description="Evening health notifications at 8 PM" || echo "   Evening job may already exist"

echo "✅ Cloud Scheduler jobs created successfully"
echo ""

# Test the functions
echo "🧪 Testing deployed functions..."

# Test scheduler function
echo "   Testing scheduler function..."
SCHEDULER_RESPONSE=$(curl -s -X POST "$SCHEDULER_URL" \
  -H "Content-Type: application/json" \
  -d '{"type":"test"}')

if [ $? -eq 0 ]; then
    echo "   ✅ Scheduler function test successful"
else
    echo "   ❌ Scheduler function test failed"
fi

# Test delivery function
echo "   Testing delivery function..."
DELIVERY_RESPONSE=$(curl -s -X POST "$DELIVERY_URL" \
  -H "Content-Type: application/json" \
  -d '{"userId":"test"}')

if [ $? -eq 0 ]; then
    echo "   ✅ Delivery function test successful"
else
    echo "   ❌ Delivery function test failed"
fi

echo ""
echo "🎯 Next Steps:"
echo "   1. Test notifications in your Flutter app using the testing page"
echo "   2. Monitor function logs: gcloud functions logs read notification-scheduler"
echo "   3. Check Cloud Scheduler jobs: gcloud scheduler jobs list"
echo "   4. Set up monitoring and alerts in Google Cloud Console"
echo ""
echo "📚 For more information, see NOTIFICATION_DEPLOYMENT_GUIDE.md"
echo ""
echo "🚀 Deployment complete! Happy testing!"
