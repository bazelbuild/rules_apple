#include <stdio.h>
#include <string.h>
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/installation_proxy.h>

char *udid = NULL;

int main(int argc, char **argv)
{
    char *appid = argv[1];
    idevice_t device = NULL;
    instproxy_client_t client = NULL;
    char *path = NULL;

    if (IDEVICE_E_SUCCESS != idevice_new(&device, udid)) {
        fprintf(stderr, "No iOS device found, is it plugged in?\n");
        return -1;
    }

    if (INSTPROXY_E_SUCCESS != instproxy_client_start_service(device, &client, "containerpathtool")) {
        fprintf(stderr, "Could not start installation proxy service.\n");
        idevice_free(device);
        return -1;
    }

    if (INSTPROXY_E_SUCCESS != instproxy_client_get_path_for_bundle_identifier(client, appid, &path)) {
        fprintf(stderr, "Couldn't get application path.\n");
        instproxy_client_free(client);
        idevice_free(device);
        return -1;
    };

    printf("%s\n", path);
    free(path);

    instproxy_client_free(client);
    idevice_free(device);
    return 0;
}
