#!/bin/bash

# Deploy Firestore indexes for Universal Intent Matching System
echo "Deploying Firestore indexes for intent matching..."

# Deploy the indexes
firebase deploy --only firestore:indexes -f firestore_intents.indexes.json

echo "Indexes deployment complete!"
echo ""
echo "Next steps:"
echo "1. Copy the rules from firestore_intents.rules to your Firebase Console"
echo "2. Navigate to: https://console.firebase.google.com/project/suuper2/firestore/rules"
echo "3. Add the new rules to your existing rules file"
echo ""
echo "The Universal Intent Matching System is now ready to use!"