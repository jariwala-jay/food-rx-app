#!/bin/bash

# Quick Notification Testing Script
# This script helps you test notifications locally and remotely

set -e

echo "🧪 Notification System Testing Script"
echo "====================================="
echo ""

# Function to test local Flutter app
test_local_app() {
    echo "📱 Testing Local Flutter App..."
    echo "   1. Make sure your Flutter app is running"
    echo "   2. Navigate to the home page"
    echo "   3. Tap the blue notification icon (floating action button)"
    echo "   4. Use the testing page to trigger different notification types"
    echo ""
    echo "   Available tests:"
    echo "   - Health Goal Notifications (progress, streaks, completions)"
    echo "   - System Notifications (onboarding, re-engagement, meal reminders)"
    echo "   - Pantry Notifications (expiration, low stock, recipe suggestions)"
    echo "   - Notification Manager (load, mark read, clear)"
    echo ""
}

# Function to test Cloud Functions
test_cloud_functions() {
    echo "☁️  Testing Cloud Functions..."
    
    # Check if functions are deployed
    if ! gcloud functions describe notification-scheduler --region=us-central1 &> /dev/null; then
        echo "   ❌ notification-scheduler function not deployed"
        echo "   Run: ./deploy-notifications.sh"
        return 1
    fi
    
    if ! gcloud functions describe notification-delivery --region=us-central1 &> /dev/null; then
        echo "   ❌ notification-delivery function not deployed"
        echo "   Run: ./deploy-notifications.sh"
        return 1
    fi
    
    # Get function URLs
    SCHEDULER_URL=$(gcloud functions describe notification-scheduler --region=us-central1 --format="value(httpsTrigger.url)")
    DELIVERY_URL=$(gcloud functions describe notification-delivery --region=us-central1 --format="value(httpsTrigger.url)")
    
    echo "   📋 Function URLs:"
    echo "      Scheduler: $SCHEDULER_URL"
    echo "      Delivery:  $DELIVERY_URL"
    echo ""
    
    # Test scheduler function
    echo "   🧪 Testing scheduler function..."
    SCHEDULER_RESPONSE=$(curl -s -X POST "$SCHEDULER_URL" \
        -H "Content-Type: application/json" \
        -d '{"type":"test"}')
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Scheduler function test successful"
        echo "   Response: $SCHEDULER_RESPONSE"
    else
        echo "   ❌ Scheduler function test failed"
    fi
    
    echo ""
    
    # Test delivery function
    echo "   🧪 Testing delivery function..."
    DELIVERY_RESPONSE=$(curl -s -X POST "$DELIVERY_URL" \
        -H "Content-Type: application/json" \
        -d '{"userId":"test_user"}')
    
    if [ $? -eq 0 ]; then
        echo "   ✅ Delivery function test successful"
        echo "   Response: $DELIVERY_RESPONSE"
    else
        echo "   ❌ Delivery function test failed"
    fi
    
    echo ""
}

# Function to check MongoDB
test_mongodb() {
    echo "🗄️  Testing MongoDB Connection..."
    
    if [ -z "$MONGODB_URI" ]; then
        echo "   ⚠️  MONGODB_URI not set"
        echo "   Set it with: export MONGODB_URI='your-connection-string'"
        return 1
    fi
    
    # Test MongoDB connection (basic check)
    echo "   Testing connection to MongoDB..."
    if mongosh "$MONGODB_URI" --eval "db.adminCommand('ping')" &> /dev/null; then
        echo "   ✅ MongoDB connection successful"
        
        # Check notification collections
        echo "   Checking notification collections..."
        COLLECTIONS=$(mongosh "$MONGODB_URI" --eval "db.getCollectionNames()" --quiet | grep -o 'notifications\|notification_preferences\|notification_analytics' || true)
        
        if [ -n "$COLLECTIONS" ]; then
            echo "   ✅ Notification collections found: $COLLECTIONS"
        else
            echo "   ⚠️  No notification collections found (they will be created automatically)"
        fi
    else
        echo "   ❌ MongoDB connection failed"
        echo "   Check your MONGODB_URI and network connectivity"
    fi
    
    echo ""
}

# Function to show monitoring commands
show_monitoring() {
    echo "📊 Monitoring Commands..."
    echo ""
    echo "   View Cloud Function logs:"
    echo "   gcloud functions logs read notification-scheduler --limit=50"
    echo "   gcloud functions logs read notification-delivery --limit=50"
    echo ""
    echo "   View Cloud Scheduler jobs:"
    echo "   gcloud scheduler jobs list"
    echo ""
    echo "   View Flutter app logs:"
    echo "   flutter logs"
    echo ""
    echo "   Check MongoDB notifications:"
    echo "   mongosh \"\$MONGODB_URI\" --eval \"db.notifications.find().sort({createdAt: -1}).limit(10)\""
    echo ""
}

# Main menu
show_menu() {
    echo "What would you like to test?"
    echo ""
    echo "1) Test Local Flutter App"
    echo "2) Test Cloud Functions"
    echo "3) Test MongoDB Connection"
    echo "4) Show Monitoring Commands"
    echo "5) Run All Tests"
    echo "6) Exit"
    echo ""
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            test_local_app
            ;;
        2)
            test_cloud_functions
            ;;
        3)
            test_mongodb
            ;;
        4)
            show_monitoring
            ;;
        5)
            test_local_app
            test_mongodb
            test_cloud_functions
            show_monitoring
            ;;
        6)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please try again."
            echo ""
            show_menu
            ;;
    esac
}

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "⚠️  Google Cloud CLI not found. Some tests will be skipped."
    echo ""
fi

# Check if mongosh is available
if ! command -v mongosh &> /dev/null; then
    echo "⚠️  MongoDB Shell not found. MongoDB tests will be skipped."
    echo ""
fi

# Run the menu
show_menu

echo ""
echo "🔄 Run this script again anytime to test your notification system!"
echo "   ./test-notifications.sh"
