
import React from "react";
import CopyToClipboard from "react-copy-to-clipboard";
import { toast } from "react-toastify";
import { ToastOptionsShortcuts } from "../../utils";
import { classNames } from "../../utils";


type TCopyClipboardProps = {
    componentProps: Omit<CopyToClipboard.Props, 'children'>;
    className?: string;
    label?: string;
    labelClassName?: string;
    iconContainerClassName?: string;
}

const CopyClipboard = (props: TCopyClipboardProps) => {
    const {
        componentProps,
        className,
        label,
        labelClassName,
        iconContainerClassName,
    } = props;

    return (
        <CopyToClipboard
            {...componentProps}
            text={componentProps.text}
            onCopy={componentProps.onCopy
                ? componentProps.onCopy
                : () => toast.success('Copied', ToastOptionsShortcuts.CopyMessage)
            }
        >
            <div className={classNames('flex items-center', className)}>
                {label && (
                    <div className={classNames('cursor-pointer mr-2', labelClassName)}>{label}</div>
                )}
                <button type="button" className={iconContainerClassName}>
                    
                </button>
            </div>
        </CopyToClipboard>
    );
}

export default CopyClipboard;
