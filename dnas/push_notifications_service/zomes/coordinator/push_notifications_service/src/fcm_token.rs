use hdk::prelude::*;
use push_notifications_service_integrity::*;
use push_notifications_types::RegisterFcmTokenInput;

#[hdk_extern]
pub fn register_fcm_token_for_agent(input: RegisterFcmTokenInput) -> ExternResult<()> {
    let links = get_links(
        GetLinksInputBuilder::try_new(input.agent.clone(), LinkTypes::FcmToken)?.build(),
    )?;

    for link in links {
        delete_link(link.create_link_hash)?;
    }

    create_link(
        input.agent.clone(),
        input.agent,
        LinkTypes::FcmToken,
        input.token.as_bytes().to_vec(),
    )?;

    Ok(())
}

pub fn get_fcm_token_for_agent(agent: AgentPubKey) -> ExternResult<Option<String>> {
    let links =
        get_links(GetLinksInputBuilder::try_new(agent.clone(), LinkTypes::FcmToken)?.build())?;

    let Some(link) = links.first().cloned() else {
        return Ok(None);
    };

    let token = String::from_utf8(link.tag.into_inner()).map_err(|err| {
        wasm_error!(WasmErrorInner::Guest(format!(
            "Malformed token tag {err:?}"
        )))
    })?;

    Ok(Some(token))
}
