export const NotifyWhenIdle = async ({ $ }) => ({
  event: async ({ event }) => {
    if (event.type === "session.idle") {
      await $`[COMMAND_PATH]/notify-if-unfocused.sh`.nothrow();
    }
  },
});
