export const NotifyWhenIdle = async ({ $ }) => ({
  event: async ({ event }) => {
    if (event.type === "session.idle") {
      await $`powershell -NoProfile -ExecutionPolicy Bypass -File [COMMAND_PATH]/notify-if-unfocused.ps1`.nothrow();
    }
  },
});
