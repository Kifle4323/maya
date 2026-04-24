// Firebase Cloud Messaging Service Worker
// Required for background push notifications on web.
// This file must be at the root of the web/ directory.

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCd04uZ9izKUsYpDLQ_6ZEjgf9XtIMCf8k',
  authDomain: 'maya-city-cbhi.firebaseapp.com',
  projectId: 'maya-city-cbhi',
  storageBucket: 'maya-city-cbhi.firebasestorage.app',
  messagingSenderId: '807775792445',
  appId: '1:807775792445:web:ef4de33dbbc9b63feda954',
});

const messaging = firebase.messaging();

// Handle background messages (app is closed or in background tab)
messaging.onBackgroundMessage((payload) => {
  console.log('[FCM SW] Background message:', payload);

  const title = payload.notification?.title ?? 'CBHI Admin';
  const body = payload.notification?.body ?? '';
  const icon = '/icons/Icon-192.png';

  return self.registration.showNotification(title, { body, icon });
});
