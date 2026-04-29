importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCUYIBBQnaR0EzfrPvP7n2qxZZz0rz8ubs",
  authDomain: "maya-71797.firebaseapp.com",
  projectId: "maya-71797",
  storageBucket: "maya-71797.firebasestorage.app",
  messagingSenderId: "29920872141",
  appId: "1:29920872141:web:994fea511f203782ea8b84",
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
