use crate::load_protos;
use crate::{Flag, FlagSource};
use crate::{FlagPermission, FlagValue, ValuePickedFrom};
use aconfigd_protos::{
    ProtoFlagQueryReturnMessage, ProtoListStorageMessage, ProtoListStorageMessageMsg,
    ProtoStorageRequestMessage, ProtoStorageRequestMessageMsg, ProtoStorageRequestMessages,
    ProtoStorageReturnMessage, ProtoStorageReturnMessageMsg, ProtoStorageReturnMessages,
};
use anyhow::anyhow;
use anyhow::Result;
use protobuf::Message;
use protobuf::SpecialFields;
use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::Shutdown;
use std::os::unix::net::UnixStream;

pub struct AconfigStorageSource {}

static ACONFIGD_SYSTEM_SOCKET_NAME: &str = "/dev/socket/aconfigd_system";
static ACONFIGD_MAINLINE_SOCKET_NAME: &str = "/dev/socket/aconfigd_mainline";

enum AconfigdSocket {
    System,
    Mainline,
}

impl AconfigdSocket {
    pub fn name(&self) -> &str {
        match self {
            AconfigdSocket::System => ACONFIGD_SYSTEM_SOCKET_NAME,
            AconfigdSocket::Mainline => ACONFIGD_MAINLINE_SOCKET_NAME,
        }
    }
}

fn load_flag_to_container() -> Result<HashMap<String, String>> {
    Ok(load_protos::load()?.into_iter().map(|p| (p.qualified_name(), p.container)).collect())
}

fn convert(msg: ProtoFlagQueryReturnMessage, containers: &HashMap<String, String>) -> Result<Flag> {
    let (value, value_picked_from) = match (
        &msg.boot_flag_value,
        msg.default_flag_value,
        msg.local_flag_value,
        msg.has_local_override,
    ) {
        (_, _, Some(local), Some(has_local)) if has_local => {
            (FlagValue::try_from(local.as_str())?, ValuePickedFrom::Local)
        }
        (Some(boot), Some(default), _, _) => {
            let value = FlagValue::try_from(boot.as_str())?;
            if *boot == default {
                (value, ValuePickedFrom::Default)
            } else {
                (value, ValuePickedFrom::Server)
            }
        }
        _ => return Err(anyhow!("missing override")),
    };

    let staged_value = match (msg.boot_flag_value, msg.server_flag_value, msg.has_server_override) {
        (Some(boot), Some(server), _) if boot == server => None,
        (Some(boot), Some(server), Some(has_server)) if boot != server && has_server => {
            Some(FlagValue::try_from(server.as_str())?)
        }
        _ => None,
    };

    let permission = match msg.is_readwrite {
        Some(is_readwrite) => {
            if is_readwrite {
                FlagPermission::ReadWrite
            } else {
                FlagPermission::ReadOnly
            }
        }
        None => return Err(anyhow!("missing permission")),
    };

    let name = msg.flag_name.ok_or(anyhow!("missing flag name"))?;
    let package = msg.package_name.ok_or(anyhow!("missing package name"))?;
    let qualified_name = format!("{package}.{name}");
    Ok(Flag {
        name,
        package,
        value,
        permission,
        value_picked_from,
        staged_value,
        container: containers
            .get(&qualified_name)
            .cloned()
            .unwrap_or_else(|| "<no container>".to_string())
            .to_string(),
        // TODO: remove once DeviceConfig is not in the CLI.
        namespace: "-".to_string(),
    })
}

fn read_from_socket(socket: AconfigdSocket) -> Result<Vec<ProtoFlagQueryReturnMessage>> {
    let messages = ProtoStorageRequestMessages {
        msgs: vec![ProtoStorageRequestMessage {
            msg: Some(ProtoStorageRequestMessageMsg::ListStorageMessage(ProtoListStorageMessage {
                msg: Some(ProtoListStorageMessageMsg::All(true)),
                special_fields: SpecialFields::new(),
            })),
            special_fields: SpecialFields::new(),
        }],
        special_fields: SpecialFields::new(),
    };

    let mut socket = UnixStream::connect(socket.name())?;

    let message_buffer = messages.write_to_bytes()?;
    let mut message_length_buffer: [u8; 4] = [0; 4];
    let message_size = &message_buffer.len();
    message_length_buffer[0] = (message_size >> 24) as u8;
    message_length_buffer[1] = (message_size >> 16) as u8;
    message_length_buffer[2] = (message_size >> 8) as u8;
    message_length_buffer[3] = *message_size as u8;
    socket.write_all(&message_length_buffer)?;
    socket.write_all(&message_buffer)?;
    socket.shutdown(Shutdown::Write)?;

    let mut response_length_buffer: [u8; 4] = [0; 4];
    socket.read_exact(&mut response_length_buffer)?;
    let response_length = u32::from_be_bytes(response_length_buffer) as usize;
    let mut response_buffer = vec![0; response_length];
    socket.read_exact(&mut response_buffer)?;

    let response: ProtoStorageReturnMessages =
        protobuf::Message::parse_from_bytes(&response_buffer)?;

    match response.msgs.as_slice() {
        [ProtoStorageReturnMessage {
            msg: Some(ProtoStorageReturnMessageMsg::ListStorageMessage(list_storage_message)),
            ..
        }] => Ok(list_storage_message.flags.clone()),
        _ => Err(anyhow!("unexpected response from aconfigd")),
    }
}

impl FlagSource for AconfigStorageSource {
    fn list_flags() -> Result<Vec<Flag>> {
        let containers = load_flag_to_container()?;
        let system_messages = read_from_socket(AconfigdSocket::System);
        let mainline_messages = read_from_socket(AconfigdSocket::Mainline);

        let mut all_messages = vec![];
        if let Ok(system_messages) = system_messages {
            all_messages.extend_from_slice(&system_messages);
        }
        if let Ok(mainline_messages) = mainline_messages {
            all_messages.extend_from_slice(&mainline_messages);
        }

        all_messages
            .into_iter()
            .map(|query_message| convert(query_message.clone(), &containers))
            .collect()
    }

    fn override_flag(_namespace: &str, _qualified_name: &str, _value: &str) -> Result<()> {
        todo!()
    }
}
