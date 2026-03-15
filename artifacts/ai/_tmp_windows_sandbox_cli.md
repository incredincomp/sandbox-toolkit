---
layout: Conceptual
title: Windows Sandbox command line | Microsoft Learn
canonicalUrl: https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-cli
ms.subservice: itpro-security
ms.service: windows-client
recommendations: true
adobe-target: true
ms.collection:
- tier2
breadcrumb_path: /windows/resources/breadcrumb/toc.json
uhfHeaderId: MSDocsHeader-Windows
ms.localizationpriority: medium
manager: bpardi
feedback_system: Standard
feedback_product_url: https://support.microsoft.com/windows/send-feedback-to-microsoft-with-the-feedback-hub-app-f59187f8-8739-22d6-ba93-f66612949332
author: officedocspr5
ms.author: odocspr
description: Windows Sandbox command line interface
ms.topic: how-to
ms.date: 2024-10-22T00:00:00.0000000Z
locale: en-us
document_id: 459e3ffb-cbd8-3559-bb5b-486348778daa
document_version_independent_id: 459e3ffb-cbd8-3559-bb5b-486348778daa
updated_at: 2025-01-24T11:23:00.0000000Z
original_content_git_url: https://github.com/MicrosoftDocs/windows-docs-pr/blob/live/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-cli.md
gitcommit: https://github.com/MicrosoftDocs/windows-docs-pr/blob/b34d3f8baadc0a6e220399a86b5a9a4e1a12cc58/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-cli.md
git_commit_id: b34d3f8baadc0a6e220399a86b5a9a4e1a12cc58
site_name: Docs
depot_name: TechNet.windows-security
page_type: conceptual
toc_rel: toc.json
pdf_url_template: https://learn.microsoft.com/pdfstore/en-us/TechNet.windows-security/{branchName}{pdfName}
feedback_help_link_type: ''
feedback_help_link_url: ''
word_count: 685
asset_id: application-security/application-isolation/windows-sandbox/windows-sandbox-cli
moniker_range_name: 
monikers: []
item_type: Content
source_path: windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-cli.md
cmProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/bcbcbad5-4208-4783-8035-8481272c98b8
spProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/43b2e5aa-8a6d-4de2-a252-692232e5edc8
platformId: f567235b-6ee8-5238-c86d-0e13e8ca96b1
---

# Windows Sandbox command line | Microsoft Learn

Starting with Windows 11, version 24H2, the Windows Command Line Interface (CLI) offers powerful tools for creating, managing, and controlling sandboxes, executing commands, and sharing folders within sandbox sessions. This functionality is especially valuable for scripting, task automation, and improving development workflows. In this section, you'll explore how the Windows Sandbox CLI operates, with examples demonstrating how to use each command to enhance your development process.

**Common parameters**:

- `--raw`: Formats all outputs in JSON format.
- `-?, -h, --help`: Show help and usage information

## Start

The start command creates and launches a new sandbox. The command returns the sandbox ID, which is a unique identifier for the sandbox. The sandbox ID can be used to refer to the sandbox in other commands.

- `--id <id>`: ID of the Windows Sandbox environment.
- `--c, --config <config>`: Formatted string with the settings that should be used to create the Windows Sandbox environment.

**Examples**:

- Create a Windows Sandbox environment with the default settings:

    ```cmd
    wsb start
    ```
- Create a Windows Sandbox environment with a custom configuration:

    ```cmd
    wsb start --config "<Configuration><Networking>Disabled</Networking></Configuration>"
    ```

## List

The list command displays a table that shows the information the running Windows Sandbox sessions for the current user. The table includes the sandbox ID. The status can be either running or stopped. The uptime is the duration that the sandbox has been running.

```cmd
wsb list
```

## Exec

The exec command executes a command in the sandbox. The command takes two arguments: the sandbox ID and the command to execute. The command can be either a built-in command or an executable file. The exec command runs the command in the sandbox and returns the exit code. The exec command can also take optional arguments that are passed to the process started in the sandbox.

Note

Currently, there is no support for process I/O meaning that there is no way to retrieve the output of a command run in Sandbox.

An active user session is required to execute a command in the context of the currently logged on user. Therefore, before running this command a remote desktop connection should be established. This can be done using the connect command.

- `--id <id>` (REQUIRED): ID of the Windows Sandbox environment.
- `-c, --command <command>` (REQUIRED): The command to execute within Windows Sandbox.
- `-r, --run-as <ExistingLogin|System>` (REQUIRED): Specifies the user context to execute the command within. If the System option is selected, the command runs in the system context. If the ExistingLogin option is selected, the command runs in the currently active user session or fails if there's no active user session.
- `-d, --working-directory <directory>`: Directory to execute command in.

```cmd
wsb exec –-id 12345678-1234-1234-1234-1234567890AB -c app.exe -r System
```

## Stop

The stop command stops a running Windows Sandbox session. The command takes the sandbox ID as an argument.

The stop command terminates the sandbox process and releases the resources allocated to the sandbox. The stop command also closes the window that shows the sandbox desktop.

```cmd
wsb stop --id 12345678-1234-1234-1234-1234567890AB
```

## Share

The share command shares a host folder with the sandbox. The command takes three arguments: the sandbox ID, the host path, and the sandbox path. The host path should be a folder. The sandbox path can be either an existing or a new folder. An Additional, `--allow-write` option can be used to allow or disallow the Windows Sandbox environment to write to the folder.

- `--id <id>` (REQUIRED): ID of the Windows Sandbox environment.
- `-f, --host-path <host-path>` (REQUIRED): Path to folder that is shared from the host.
- `-s, --sandbox-path <sandbox-path>` (REQUIRED): Path to the folder within the Windows Sandbox.
- `-w, --allow-write`: If specified, the Windows Sandbox environment is allowed to write to the shared folder.

```cmd
wsb share --id 12345678-1234-1234-1234-1234567890AB -f C:\host\folder -s C:\sandbox\folder --allow-write
```

## Connect

The connect command starts a remote session within the sandbox. The command takes the sandbox ID as an argument. The connect command opens a new window with a remote desktop session. The connect command allows the user to interact with the sandbox using the mouse and keyboard.

```cmd
wsb connect --id 12345678-1234-1234-1234-1234567890AB
```

## IP

The ip command displays the IP address of the sandbox. The command takes the sandbox ID as an argument.

```cmd
wsb ip --id 12345678-1234-1234-1234-1234567890AB
```
