importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in your app's Firebase config object.
// https://firebase.google.com/docs/web/setup#config-object
firebase.initializeApp({
  apiKey: "AIzaSyDo4I23vJSBeKfqQ-k7FsW7VRQqXS2Bfuk",
  authDomain: "superdating-f3bb0.firebaseapp.com",
  projectId: "superdating-f3bb0",
  storageBucket: "superdating-f3bb0.firebasestorage.app",
  messagingSenderId: "647547334104",
  appId: "1:647547334104:web:35fc0c59c3d088f35501f1",
  measurementId: "G-J9TX10Q65Q"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/firebase-logo.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});