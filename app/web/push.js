// GymQuest — pont JS pour l'abonnement aux notifications push, appelé
// depuis Dart via dart:js_util (voir lib/services/push_service.dart).

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

window.gymquestPush = {
  isSupported: function () {
    return 'serviceWorker' in navigator && 'PushManager' in window;
  },
  subscribe: async function (vapidPublicKey) {
    if (!window.gymquestPush.isSupported()) {
      throw new Error('Notifications non supportées par ce navigateur.');
    }
    const reg = await navigator.serviceWorker.register('push-sw.js');
    await navigator.serviceWorker.ready;
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      throw new Error('Permission de notification refusée.');
    }
    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      });
    }
    return JSON.stringify(sub.toJSON());
  },
};
